
import SwiftUI



class I2CMasterController: I2CController {
    
    enum TransmissionControlState {
        case ready
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
        case ready
        case starting
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
        case completed
        case addressNacked
        var isTransmittingAck: Bool { return self == .transmittingAddressAck || self == .transmittingDataAck }
        var isTransmittingByte: Bool { return self == .transmittingAddressByte || self == .transmittingDataByte }
    }
    
    enum TransmissionResult {
        case success(writtenBytes: [Byte], readBytes: [Byte])
        case addressNack
        case aborted
    }
    
    var currentTransmissionControlState: TransmissionControlState = .ready
    var currentTransmissionStatus: TransmissionStatus = .ready
    var lastTransmissionResult: TransmissionResult?
    
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)
    var busBusy = false

    var lastLineChangeX: CGFloat?
    var lastIdleReachedX: CGFloat?
    var lastBitClockHighStartX: CGFloat?
    var lastBitClockLowStartX: CGFloat?
    var lastStopX: CGFloat?
    
    let xWaitAfterStop: CGFloat = 100
    let xWaitBeforeStart: CGFloat = 30
    let xBitClockHighDuration: CGFloat = 30
    let xBitClockLowDuration: CGFloat = 30
    let xWaitAfterLineChange: CGFloat = 10
    
    var scheduledTransmissions: [(x: CGFloat, transmission: I2CTransmission)] = []
    var activeTransmission: I2CTransmission?
    
    var holdingBus = false
    var nextBitToWrite: Bit?
    
    var lastTransmittedBit: Bit?
    var lastTransmittedAck: Ack?
    
    var transmittedDataBytes: [Byte] = []
    var currentTransmittedByteReadBits: [Bit] = []
    
    var currentTransmittedByteIndex: Int = 0
    var currentTransmittedByteBitIndex: Int { currentTransmittedByteReadBits.count }
    
    let onTransmissionEnded: ((TransmissionResult)->())?
    
    
    init(onTransmissionEnded: ((TransmissionResult)->())?) {
        
        self.onTransmissionEnded = onTransmissionEnded
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append((x: x, transmission: transmission))
    }
    
    
    override func reset(x: CGFloat) {
    
        clearActiveTransmission()
        
        lastKnownLineLevels = bus.currentLineLevels
        
        self.pullingSCL = false
        self.pullingSDA = false
    }
    
    
    override func update(x: CGFloat) {
        
        if bus.currentLineLevels != lastKnownLineLevels {
            
            if detectedStartCondition(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                busBusy = true
            }
            if detectedStopCondition(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                
                busBusy = false
                lastStopX = x
                lastIdleReachedX = x
                
                if activeTransmission != nil {
                    transmissionStopped()
                }
            }
            if bus.currentLineLevels == (SCL: .high, SDA: .high) {
                lastIdleReachedX = x
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
            
            case .ready:
                break
                
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
    
    
    func waited(_ duration: CGFloat, relativeTo ref: CGFloat?, x: CGFloat) -> Bool {
        
        if let ref = ref {
            return (x - ref) >= duration
        } else {
            return true
        }
    }
    
    
    func updateControls(x: CGFloat) {
        
        if waited(xWaitAfterLineChange, relativeTo: lastLineChangeX, x: x) {
            
            switch currentTransmissionControlState {
                
            case .ready:
                break
                
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
                assertWriteBit()
                
            case .bit_clock_assertingSCLHigh:
                assertWriteBit()
                if waited(xBitClockLowDuration, relativeTo: lastBitClockLowStartX, x: x) {
                    self.pullingSCL = false
                }
                
            case .bit_clock_sendingBit:
                assertWriteBit()
                if waited(xBitClockHighDuration, relativeTo: lastBitClockHighStartX, x: x) {
                    self.pullingSCL = true
                }
                
            case .stop_setup_assertingSCLHigh:
                self.pullingSCL = false
            
            case .stop_setup_assertingSCLLow:
                self.pullingSCL = true
                
            case .stop_setup_assertingSDALow:
                self.pullingSDA = true
            
            case .stop_releasingSDA:
                self.pullingSDA = false
                
            case .stopped:
                self.pullingSCL = false
                self.pullingSDA = false
            }
        }
    }
    
    
    func assertWriteBit() {
        
        self.pullingSDA = nextBitToWrite == .zero
    }


    func clearActiveTransmission() {
        
        self.activeTransmission = nil
        
        currentTransmissionControlState = .ready
        currentTransmissionStatus = .ready
        lastTransmissionResult = nil
    }
    
    
    func startActiveTransmission(x: CGFloat) {
        
        currentTransmissionStatus = .starting
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
        
        currentTransmissionStatus = .transmittingAddressByte
        initiateNextBit()
    }
    
    
    func initiateNextDataByte() {
        
        currentTransmissionStatus = .transmittingDataByte
        initiateNextBit()
    }
    
    
    var nextControlStateToStartBit: TransmissionControlState {
        
        if bus.lineSCL.isHigh {
            return .bit_setup_assertingSCLLow
        } else {
            return .bit_setup_assertingSDA
        }
    }
    
    func initiateNextBit() {
        
        prepareNextBit()
        currentTransmissionControlState = nextControlStateToStartBit
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
        
        lastTransmittedBit = bus.lineSDA.currentLevel.bit
    }
    
    func bitClockHighPhaseEnded() {
        
        if currentTransmissionStatus.isTransmittingAck {
            
            lastTransmittedAck = Ack(from: lastTransmittedBit!)
            if lastTransmittedAck == .ack {
                
                let hasMoreBytes = (currentTransmittedByteIndex+1) < activeTransmission!.numBytes
                if hasMoreBytes {
                    
                    if currentTransmissionStatus == .transmittingAddressAck {
                        currentTransmittedByteIndex = 0
                    }
                    if currentTransmissionStatus == .transmittingDataAck {
                        currentTransmittedByteIndex += 1
                    }
                    
                    initiateNextDataByte()
                } else {
                    currentTransmissionStatus = .completed
                    initiateStop()
                }
                
            } else {
                
                if currentTransmissionStatus == .transmittingAddressAck {
                    currentTransmissionStatus = .addressNacked
                }
                initiateStop()
            }
        }
            
        if currentTransmissionStatus.isTransmittingByte {
            
            currentTransmittedByteReadBits.append(lastTransmittedBit!)
            if currentTransmittedByteReadBits.count == 8 {
                
                if currentTransmissionStatus == .transmittingAddressByte {
                    currentTransmissionStatus = .transmittingAddressAck
                }
                if currentTransmissionStatus == .transmittingDataByte {
                    let byte = Byte(from: currentTransmittedByteReadBits)
                    transmittedDataBytes.append(byte)
                    currentTransmissionStatus = .transmittingDataAck
                }
                
                currentTransmittedByteReadBits = []
            }
            
            initiateNextBit()
        }
    }
    
    
    func transmissionStopped() {
        
        switch currentTransmissionStatus {
            
        case .ready:
            break
        
        case .starting,
             .transmittingAddressByte,
             .transmittingAddressAck,
             .transmittingDataByte,
             .transmittingDataAck:
            lastTransmissionResult = .aborted
            
        case .addressNacked:
            lastTransmissionResult = .addressNack
            
        case .completed:
            let isWrite = activeTransmission!.isWrite
            let isRead = activeTransmission!.isRead
            lastTransmissionResult = .success(
                writtenBytes: isWrite ? transmittedDataBytes : [],
                readBytes: isRead ? transmittedDataBytes : []
            )
        }
        
        let result = lastTransmissionResult
        clearActiveTransmission()
        if let result = result {
            onTransmissionEnded?(result)
        }
    }
    
    
    private func prepareNextBit() {

        nextBitToWrite = nil
        
        switch currentTransmissionStatus {
        
        case .ready,
             .starting:
            break
            
        case .transmittingAddressByte:
            nextBitToWrite = nextAddressBitToWrite
        
        case .transmittingAddressAck:
            break
            
        case .transmittingDataByte:
            if activeTransmission!.mode == .writeToSlave {
                nextBitToWrite = nextDataBitToWrite
            }
        
        case .transmittingDataAck:
            if activeTransmission!.mode == .readFromSlave {
                let ack = Ack(ackIf: currentTransmittedByteIndex < activeTransmission!.numBytes-1)
                nextBitToWrite = ack.bit
            }
            
        case .completed,
             .addressNacked:
            break
        }
    }


    var nextAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }


    var nextDataBitToWrite: Bit? {

        if currentTransmittedByteIndex < activeTransmission!.bytes.count {
            let byte = activeTransmission!.bytes[currentTransmittedByteIndex]
            return byte.bit(atIndex: currentTransmittedByteBitIndex)
        } else {
            return nil
        }
    }
}
