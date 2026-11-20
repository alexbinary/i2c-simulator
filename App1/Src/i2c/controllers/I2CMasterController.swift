
import SwiftUI



class I2CMasterController: I2CController {
    
    enum TransmissionControlState {
        case start_setup_assertingSDA
        case start_setup_assertingSCL
        case start_pullingSDA
        case bit_setup_assertingSCL
        case bit_setup_assertingSDA
        case bit_clock_releasingSCL
        case bit_clock_pullingSCL
        case stop_setup_assertingSCL
        case stop_setup_assertingSDA
        case stop_assertingSCL
        case stop_releasingSDA
    }
    
    enum TransmissionStep {
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
    }
    
    enum TransmissionResult {
        case success(readBytes: [Byte])
        case addressNack
        case error
    }
    
    var currentTransmissionControlState: TransmissionControlState = .start_setup_assertingSDA
    var currentTransmissionStep: TransmissionStep = .transmittingAddressByte
    var currentTransmissionResult: TransmissionResult?
    
    var currentLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)

    var lastLineChangeX: CGFloat = 0
    let xWaitAfterLineChange: CGFloat = 10
    
    var scheduledTransmissions: [(x: CGFloat, transmission: I2CTransmission)] = []
    var activeTransmission: I2CTransmission? = nil
    var addressAcked: Bool = false
    
    var sendingStop = false
    var holdingBus = false
    var writingBit = false
    var nextBitToWrite: Bit?
    
    var lastReadBit: Bit? = nil
    var lastReadByte: UInt8? = nil
    
    var readAddressByte: UInt8? = nil
    var readDataBytes: [UInt8] = []
    var currentByteReadBits: [Bit] = []
    
    var currentByteIndex: Int = 0
    var currentByteBitIndex: Int { currentByteReadBits.count }
    
    let onReadSuccess: (([UInt8])->())?
    
    
    init(onReadSuccess: (([UInt8])->())?) {
        
        self.onReadSuccess = onReadSuccess
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append((x: x, transmission: transmission))
    }
    
    
    override func initState(x: CGFloat) {
    
    }
    
    
    override func updateBusControl(x: CGFloat) {

        if activeTransmission == nil {
            
            if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= x {
                
                scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                activeTransmission = entry.transmission
                
                resetTransmissionState(x: x)
            }
        }
        
        if activeTransmission != nil {
            
            let previousLineLevels = currentLineLevels
            currentLineLevels = bus.currentLineLevels
            
            if currentLineLevels.SCL != previousLineLevels.SCL {
                lastLineChangeX = x
            }
            if currentLineLevels.SDA != previousLineLevels.SDA {
                lastLineChangeX = x
            }
            
            updateTransmissionDriveState(x: x)
            updateControls(x: x)
        }
    }
    
    
    func onReadAddressByte(byte: Byte) {
    }
    
    
    func onReadAddressAck(ack: Ack) {
        switch ack {
        case .ack:
            addressAcked = true
        case .nack:
            sendingStop = true
        }
    }
    
    
    func onReadDataByte(byte: Byte) {
    }
    
    
    func onReadDataAck(ack: Ack) {
        if ack == .nack {
            sendingStop = true
        }
    }
    
    
    func onDone(readBytes: [Byte]) {
        let readSuccess = self.activeTransmission!.mode == .read && addressAcked
        clearActiveTransmission()
        if readSuccess {
            onReadSuccess?(readBytes)
        }
    }
    

    func onAborted() {
        clearActiveTransmission()
    }
    
    
    func clearActiveTransmission() {
        
        self.activeTransmission = nil
    }
    
    
    func resetTransmissionState(x: CGFloat) {
        
        currentTransmissionControlState = .start_setup_assertingSDA
        
        currentTransmissionStep = .transmittingAddressByte
        currentTransmissionResult = nil
        
        sendingStop = false
        holdingBus = false
        
        prepareNextBit()
    }
    
    
    func transmissionError() {
        
        clearActiveTransmission()
    }
    
    
    func updateTransmissionDriveState(x: CGFloat) {
        
        while true {
            
            let previousState = currentTransmissionControlState
            
            switch currentTransmissionControlState {
                
            case .start_setup_assertingSDA:
                if bus.lineSDA.isHigh {
                    currentTransmissionControlState = .start_setup_assertingSCL
                }
                
            case .start_setup_assertingSCL:
                if bus.lineSCL.isHigh {
                    currentTransmissionControlState = .start_pullingSDA
                }
                
            case .start_pullingSDA:
                if bus.lineSDA.isLow {
                    if nextBitToWrite != nil {
                        currentTransmissionControlState = .bit_setup_assertingSCL
                    } else {
                        currentTransmissionControlState = .stop_setup_assertingSCL
                    }
                }
                
            case .bit_setup_assertingSCL:
                if bus.lineSCL.isLow {
                    currentTransmissionControlState = .bit_setup_assertingSDA
                }
                
            case .bit_setup_assertingSDA:
                if !writingBit || (nextBitToWrite == .zero && bus.lineSDA.isLow) || (nextBitToWrite == .one && bus.lineSDA.isHigh) {
                    currentTransmissionControlState = .bit_clock_releasingSCL
                }
                
            case .bit_clock_releasingSCL:
                if bus.lineSCL.isHigh {
                    currentTransmissionControlState = .bit_clock_pullingSCL
                }
                
            case .bit_clock_pullingSCL:
                if bus.lineSCL.isLow {
                    currentTransmissionControlState = .bit_setup_assertingSCL
                    transmissionExitBitClock()
                } else {
                    transmissionReadingBit()
                }
                
            case .stop_setup_assertingSCL:
                if bus.lineSCL.isLow {
                    currentTransmissionControlState = .stop_setup_assertingSDA
                }
                
            case .stop_setup_assertingSDA:
                if bus.lineSDA.isLow {
                    currentTransmissionControlState = .stop_assertingSCL
                }
                
            case .stop_assertingSCL:
                if bus.lineSCL.isHigh {
                    currentTransmissionControlState = .stop_releasingSDA
                }
                
            case .stop_releasingSDA:
                if bus.lineSDA.isHigh {
                    currentTransmissionControlState = .start_setup_assertingSDA
                    transmissionStop()
                }
            }
            
            if currentTransmissionControlState != previousState {
                continue
            } else {
                break
            }
        }
    }
    
    
    func updateControls(x: CGFloat) {
        
        if x - lastLineChangeX >= xWaitAfterLineChange {
            
            switch currentTransmissionControlState {
                
            case .start_setup_assertingSDA:
                self.pullingSDA = false
            
            case .start_setup_assertingSCL:
                self.pullingSCL = false
                
            case .start_pullingSDA:
                self.pullingSDA = true
                
            case .bit_setup_assertingSCL:
                self.pullingSCL = true
                
            case .bit_setup_assertingSDA:
                self.pullingSDA = (writingBit && nextBitToWrite == .zero)
                
            case .bit_clock_releasingSCL:
                self.pullingSCL = false
                
            case .bit_clock_pullingSCL:
                self.pullingSCL = true
                
            case .stop_setup_assertingSCL:
                self.pullingSCL = true
                
            case .stop_setup_assertingSDA:
                self.pullingSCL = true
                
            case .stop_assertingSCL:
                self.pullingSCL = false
                
            case .stop_releasingSDA:
                self.pullingSDA = false
            }
        }
    }
    
    
    func transmissionReadingBit() {
        
        lastReadBit = bus.lineSDA.currentLevel.bit
    }
    
    
    func transmissionExitBitClock() {
        
        updateTransmissionStep()
        prepareNextBit()
        
        if nextBitToWrite == nil {
            sendingStop = true
        }
    }
    
    
    func transmissionStop() {
        
        let bytes = readDataBytes
        onDone(readBytes: bytes)
    }
    
    
    private func updateTransmissionStep() {
        
        if currentTransmissionStep == .transmittingAddressAck || currentTransmissionStep == .transmittingDataAck {
            
            let ack = Ack(from: lastReadBit!)
            let step = currentTransmissionStep
            
            currentTransmissionStep = .transmittingDataByte
            
            if step == .transmittingAddressAck {
                onReadAddressAck(ack: ack)
            }
            
            if step == .transmittingDataAck {
                currentByteIndex += 1
                onReadDataAck(ack: ack)
            }
        }
        
        if currentTransmissionStep == .transmittingAddressByte || currentTransmissionStep == .transmittingDataByte {
            
            currentByteReadBits.append(lastReadBit!)
            if currentByteReadBits.count == 8 {
                
                let byte = Byte(from: currentByteReadBits)
                currentByteReadBits = []
                lastReadByte = byte
                
                if currentTransmissionStep == .transmittingAddressByte {
                    readAddressByte = byte
                    currentTransmissionStep = .transmittingAddressAck
                    onReadAddressByte(byte: byte)
                    
                }
                if currentTransmissionStep == .transmittingDataByte {
                    readDataBytes.append(byte)
                    currentTransmissionStep = .transmittingDataAck
                    onReadDataByte(byte: byte)
                }
            }
        }
    }


    private func prepareNextBit() {

        writingBit = false
        
        switch currentTransmissionStep {
        
        case .transmittingAddressByte:
            
            writingBit = true
            nextBitToWrite = nextAddressBitToWrite
        
        case .transmittingAddressAck:
            break
            
        case .transmittingDataByte:
            
            if activeTransmission!.mode == .write {
                writingBit = true
                nextBitToWrite = nextDataBitToWrite
            }
        
        case .transmittingDataAck:
        
            if activeTransmission!.mode == .read {
                writingBit = true
                let ack = currentByteIndex < activeTransmission!.numBytes-1
                nextBitToWrite = ack ? .zero : .one
            }
        }
    }


    var nextAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: currentByteBitIndex)
    }


    var nextDataBitToWrite: Bit? {

        if currentByteIndex < activeTransmission!.bytes.count {
            let byte = activeTransmission!.bytes[currentByteIndex]
            return byte.bit(atIndex: currentByteBitIndex)
        } else {
            return nil
        }
    }
}
