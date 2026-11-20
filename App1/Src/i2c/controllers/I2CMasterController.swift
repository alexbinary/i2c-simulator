
import SwiftUI



class I2CMasterController: I2CController {
    
    enum TransmissionControlState {
        case start_setup_assertingSCLHigh
        case start_setup_assertingSCLLow
        case start_setup_assertingSDAHigh
        case start_pullingSDA
        case bit_setup_assertingSCLLow
        case bit_setup_assertingSDA
        case bit_clock_assertingSCLHigh
        case bit_clock_sendingBit
        case stop_setup_assertingSCLLow
        case stop_setup_assertingSDALow
        case stop_setup_assertingSCLHigh
        case stop_releasingSDA
        case stopped
    }
    
    enum TransmissionStatus {
        case starting
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
        case completed
        case addressNacked
        var isTransmittingAck: Bool { return self == .transmittingAddressAck || self == .transmittingDataAck }
    }
    
    enum TransmissionResult {
        case success(readBytes: [Byte])
        case addressNack
        case aborted
    }
    
    var currentTransmissionControlState: TransmissionControlState = .start_setup_assertingSDAHigh
    var currentTransmissionStep: TransmissionStatus = .transmittingAddressByte
    var lastTransmissionResult: TransmissionResult?
    
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)
    var busBusy = false

    var lastLineChangeX: CGFloat = 0
    var lastIdleReachedX: CGFloat = 0
    var lastBitClockHighStartX: CGFloat = 0
    var lastBitClockLowStartX: CGFloat = 0
    var lastStopX: CGFloat = 0
    
    let xWaitAfterLineChange: CGFloat = 10
    let xWaitBeforeStart: CGFloat = 30
    let xBitClockHighDuration: CGFloat = 30
    let xBitClockLowDuration: CGFloat = 30
    let xWaitAfterStop: CGFloat = 100
    
    var scheduledTransmissions: [(x: CGFloat, transmission: I2CTransmission)] = []
    var activeTransmission: I2CTransmission?
    
    var holdingBus = false
    var nextBitToWrite: Bit?
    
    var lastReadBit: Bit?
    var lastReadAck: Ack?
    
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
    
        lastKnownLineLevels = bus.currentLineLevels
        
        self.pullingSCL = false
        self.pullingSDA = false
    }
    
    
    override func updateBusControl(x: CGFloat) {
        
        if bus.currentLineLevels != lastKnownLineLevels {
            
            if detectedStartCondition(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                busBusy = true
            }
            if detectedStopCondition(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                
                busBusy = false
                lastIdleReachedX = x
                
                if activeTransmission != nil {
                    transmissionStopped()
                }
            }
            
            lastKnownLineLevels = bus.currentLineLevels
            lastLineChangeX = x
        }

        if activeTransmission == nil {
            
            if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= x {
                
                scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                activeTransmission = entry.transmission
                
                startActiveTransmission(x: x)
            }
        }
        
        if activeTransmission != nil {
            
            updateTransmissionControlState(x: x)
            updateControls(x: x)
        }
    }
    
    
    func updateTransmissionControlState(x: CGFloat) {
        
        while true {
            
            let previousState = currentTransmissionControlState
            
            switch currentTransmissionControlState {
                
            case .start_setup_assertingSCLHigh,
                 .start_setup_assertingSCLLow,
                 .start_setup_assertingSDAHigh:
                updateStartControlState()
                
            case .start_pullingSDA:
                if bus.currentLineLevels == (SCL: .high, SDA: .low) {
                    initiateAddress()
                } else {
                    updateStartControlState()
                }
                
            case .bit_setup_assertingSCLLow:
                if bus.lineSCL.isLow {
                    currentTransmissionControlState = .bit_setup_assertingSDA
                    lastBitClockLowStartX = x
                }
                
            case .bit_setup_assertingSDA:
                if nextBitToWrite == nil || bus.lineSDA.currentLevel.bit == nextBitToWrite {
                    currentTransmissionControlState = .bit_clock_assertingSCLHigh
                }
                
            case .bit_clock_assertingSCLHigh:
                if bus.lineSCL.isHigh {
                    currentTransmissionControlState = .bit_clock_sendingBit
                    lastBitClockHighStartX = x
                }
                
            case .bit_clock_sendingBit:
                if bus.lineSCL.isHigh {
                    bitClockHighPhaseActive()
                } else {
                    currentTransmissionControlState = .bit_setup_assertingSDA
                    lastBitClockLowStartX = x
                    bitClockHighPhaseEnded()
                }
                
            case .stop_setup_assertingSCLLow,
                 .stop_setup_assertingSCLHigh,
                 .stop_setup_assertingSDALow:
                updateStopControlState()
                
            case .stop_releasingSDA:
                if bus.lineSDA.isHigh {
                    currentTransmissionControlState = .stopped
                    lastStopX = x
                    transmissionStopped()
                }
                
            case .stopped:
                break
            }
            
            if currentTransmissionControlState != previousState {
                continue
            } else {
                break
            }
        }
    }
    
    
    func waited(_ duration: CGFloat, relativeTo ref: CGFloat, x: CGFloat) -> Bool {
        
        return (x - ref) >= duration
    }
    
    
    func updateControls(x: CGFloat) {
        
        if waited(xWaitAfterLineChange, relativeTo: lastLineChangeX, x: x) {
            
            switch currentTransmissionControlState {
                
            case .start_setup_assertingSCLHigh:
                self.pullingSCL = false
            
            case .start_setup_assertingSCLLow:
                self.pullingSCL = true
            
            case .start_setup_assertingSDAHigh:
                self.pullingSDA = false
            
            case .start_pullingSDA:
                if !busBusy,
                   waited(xWaitAfterStop, relativeTo: lastStopX, x: x),
                   waited(xWaitBeforeStart, relativeTo: lastIdleReachedX, x: x) {
                    self.pullingSDA = true
                }
                
            case .bit_setup_assertingSCLLow:
                self.pullingSCL = true
                
            case .bit_setup_assertingSDA:
                self.pullingSDA = nextBitToWrite == .zero
                
            case .bit_clock_assertingSCLHigh:
                if waited(xBitClockLowDuration, relativeTo: lastBitClockLowStartX, x: x) {
                    self.pullingSCL = false
                }
                
            case .bit_clock_sendingBit:
                if waited(xBitClockHighDuration, relativeTo: lastBitClockHighStartX, x: x) {
                    self.pullingSCL = true
                }
                
            case .stop_setup_assertingSCLHigh:
                self.pullingSCL = false
            
            case .stop_setup_assertingSCLLow:
                self.pullingSCL = true
                
            case .stop_setup_assertingSDALow:
                self.pullingSCL = true
            
            case .stop_releasingSDA:
                self.pullingSDA = false
                
            case .stopped:
                self.pullingSCL = false
                self.pullingSDA = false
            }
        }
    }


    func clearActiveTransmission() {
        
        self.activeTransmission = nil
    }
    
    
    func startActiveTransmission(x: CGFloat) {
        
        currentTransmissionStep = .starting
        
        lastTransmissionResult = nil
        holdingBus = false
        
        initiateStart()
    }
    
    
    var nextControlStateToStart: TransmissionControlState {
        
        switch bus.currentLineLevels {
        case (SCL: .high, SDA: .high): return .start_pullingSDA
        case (SCL: .high, SDA: .low): return .start_setup_assertingSCLLow
        case (SCL: .low, SDA: .high): return .start_setup_assertingSCLHigh
        case (SCL: .low, SDA: .low): return .start_setup_assertingSDAHigh
        }
    }
    
    func updateStartControlState() {
        
        currentTransmissionControlState = nextControlStateToStart
    }
    
    func initiateStart() {
        
        updateStartControlState()
    }
    
    
    func initiateAddress() {
        
        currentTransmissionStep = .transmittingAddressByte
        initiateNextBit()
    }
    
    
    func initiateNextDataByte() {
        
        if currentByteIndex < activeTransmission!.bytes.count {
            initiateNextBit()
        } else {
            initiateStop()
        }
    }
    
    
    func initiateNextBit() {
        
        prepareNextBit()
        
        if bus.lineSCL.isHigh {
            currentTransmissionControlState = .bit_setup_assertingSCLLow
        } else {
            currentTransmissionControlState = .bit_setup_assertingSDA
        }
    }
    
    
    var nextControlStateToStop: TransmissionControlState {
        
        switch bus.currentLineLevels {
        case (SCL: .high, SDA: .high): return .stop_setup_assertingSCLLow
        case (SCL: .high, SDA: .low): return .stop_releasingSDA
        case (SCL: .low, SDA: .high): return .stop_setup_assertingSDALow
        case (SCL: .low, SDA: .low): return .stop_setup_assertingSCLHigh
        }
    }
    
    func updateStopControlState() {
        
        currentTransmissionControlState = nextControlStateToStop
    }
    
    func initiateStop() {
        
        updateStopControlState()
    }
    
    
    func bitClockHighPhaseActive() {
        
        lastReadBit = bus.lineSDA.currentLevel.bit
    }
    
    
    func bitClockHighPhaseEnded() {
        
        if currentTransmissionStep.isTransmittingAck {
            
            lastReadAck = Ack(from: lastReadBit!)
            let step = currentTransmissionStep
            
            if lastReadAck == .ack {
                
                let hasMoreBytes = (currentByteIndex+1) < activeTransmission!.numBytes
                if hasMoreBytes {
                    currentTransmissionStep = .transmittingDataByte
                    
                    if step == .transmittingAddressAck {
                        currentByteIndex = 0
                    }
                    if step == .transmittingDataAck {
                        currentByteIndex += 1
                    }
                    
                } else {
                    currentTransmissionStep = .completed
                }
                
            } else {
            }
            
            ackReceived()
            
        } else {
            
            currentByteReadBits.append(lastReadBit!)
            if currentByteReadBits.count == 8 {
                
                if currentTransmissionStep == .transmittingAddressByte {
                    currentTransmissionStep = .transmittingAddressAck
                }
                if currentTransmissionStep == .transmittingDataByte {
                    let byte = Byte(from: currentByteReadBits)
                    readDataBytes.append(byte)
                    currentTransmissionStep = .transmittingDataAck
                }
                
                currentByteReadBits = []
            }
        }
    }
    
    
    func ackReceived() {
        
        if currentTransmissionStep != .completed {
            initiateNextDataByte()
        } else {
            initiateStop()
        }
    }
    
    
    func transmissionStopped() {
        
        switch currentTransmissionStep {
        case .starting:
            lastTransmissionResult = .aborted
            
        case .transmittingAddressByte:
            lastTransmissionResult = .aborted
            
        case .transmittingAddressAck:
            lastTransmissionResult = .aborted
            
        case .transmittingDataByte:
            lastTransmissionResult = .aborted
            
        case .transmittingDataAck:
            lastTransmissionResult = .aborted
            
        case .addressNacked
            lastTransmissionResult = .addressNack
            
        case .completed:
            let wasReading = self.activeTransmission!.mode == .read
            lastTransmissionResult = .success(readBytes: wasReading ? readDataBytes : [])
            clearActiveTransmission()
            if wasReading {
                onReadSuccess?(readDataBytes)
            }
        }
    }
    
    
    private func prepareNextBit() {

        nextBitToWrite = nil
        
        switch currentTransmissionStep {
        
        case .transmittingAddressByte:
            nextBitToWrite = nextAddressBitToWrite
        
        case .transmittingAddressAck:
            break
            
        case .transmittingDataByte:
            if activeTransmission!.mode == .write {
                nextBitToWrite = nextDataBitToWrite
            }
        
        case .transmittingDataAck:
            if activeTransmission!.mode == .read {
                let ack = Ack(ackIf: currentByteIndex < activeTransmission!.numBytes-1)
                nextBitToWrite = ack.bit
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
