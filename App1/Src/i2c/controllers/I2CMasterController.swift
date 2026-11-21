
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
        case dataNacked
        
        enum Phase { case byte, ack }
        var phase: Phase? { (self == .transmittingAddressByte || self == .transmittingDataByte) ? .byte : (self == .transmittingAddressAck || self == .transmittingDataAck) ? .ack : nil  }
        
        enum AddressOrData { case address, data }
        var ackTarget: AddressOrData? { self == .transmittingAddressAck ? .address : self == .transmittingDataAck ? .data : nil }
        var byteNature: AddressOrData? { self == .transmittingAddressByte ? .address : self == .transmittingDataByte ? .data : nil }
    }
    
    enum TransmissionResult {
        case addressNack
        case dataNack(transmittedBytes: [Byte])
        case success(transmittedBytes: [Byte])
        case aborted(transmittedBytes: [Byte])
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
    
    var lastTransmittedBit: Bit?
    var lastTransmittedAck: Ack?
    
    var lastTransmittedByte: Byte?
    var transmittedDataBytes: [Byte] = []
    
    var currentTransmittedByteReadBits: [Bit] = []
    var currentTransmittedByteIndex: Int = 0
    var currentTransmittedByteBitIndex: Int { currentTransmittedByteReadBits.count }
    
    var nextAck: Ack?
    
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
        
        lastTransmittedBit = nil
        lastTransmittedAck = nil
        
        lastTransmittedByte = nil
        transmittedDataBytes = []
        currentTransmittedByteReadBits = []

        nextAck = nil
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
        
        switch currentTransmissionStatus.phase! {
        case .ack:
            
            lastTransmittedAck = Ack(from: lastTransmittedBit!)
            transmittedAck()
            
        case .byte:
            
            currentTransmittedByteReadBits.append(lastTransmittedBit!)
            if currentTransmittedByteReadBits.count == 8 {
                
                lastTransmittedByte = Byte(from: currentTransmittedByteReadBits)
                currentTransmittedByteReadBits = []
                transmittedDataByte()
            }
            initiateNextBit()
        }
    }
    
    
    func transmittedAck() {
        
        let ackSentBySelf = currentTransmissionStatus.ackTarget! == .data && activeTransmission!.mode == .readFromSlave
        let ackValue = ackSentBySelf ? nextAck! : lastTransmittedAck!
        
        switch ackValue {
        case .ack:
            let hasMoreBytes = (currentTransmittedByteIndex+1) < activeTransmission!.numBytes
            switch hasMoreBytes {
            case true:
                switch currentTransmissionStatus.ackTarget! {
                case .address: currentTransmittedByteIndex = 0
                case .data: currentTransmittedByteIndex += 1
                }
                initiateNextDataByte()
                
            case false:
                currentTransmissionStatus = .completed
                initiateStop()
            }
            
        case .nack:
            switch currentTransmissionStatus.ackTarget! {
            case .address: currentTransmissionStatus = .addressNacked
            case .data:
                switch activeTransmission!.mode {
                case .writeToSlave: currentTransmissionStatus = .dataNacked
                case .readFromSlave: currentTransmissionStatus = .completed
                }
            }
            initiateStop()
        }
    }
    
    
    func transmittedDataByte() {
        
        switch currentTransmissionStatus.byteNature! {
        case .address:
            currentTransmissionStatus = .transmittingAddressAck
        case .data:
            transmittedDataBytes.append(lastTransmittedByte!)
            currentTransmissionStatus = .transmittingDataAck
            if activeTransmission!.isReadFromSlave {
                nextAck = Ack(ackIf: currentTransmittedByteIndex < activeTransmission!.numBytes-1)
            }
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
            lastTransmissionResult = .aborted(transmittedBytes: transmittedDataBytes)
            
        case .addressNacked:
            lastTransmissionResult = .addressNack
            
        case .dataNacked:
            lastTransmissionResult = .dataNack(transmittedBytes: transmittedDataBytes)
        
        case .completed:
            lastTransmissionResult = .success(transmittedBytes: transmittedDataBytes)
        }
        
        let result = lastTransmissionResult
        clearActiveTransmission()
        if let result = result {
            onTransmissionEnded?(result)
        }
    }
     
    
    var nextBitToWrite: Bit? {

        switch currentTransmissionStatus {
        
        case .ready,
             .starting,
             .completed,
             .addressNacked,
             .dataNacked,
             .transmittingAddressAck:
            return nil
            
        case .transmittingAddressByte:
            return nextAddressBitToWrite
        
        case .transmittingDataByte:
            switch activeTransmission!.mode {
            case .writeToSlave: return nextDataBitToWrite
            case .readFromSlave: return nil
            }
        
        case .transmittingDataAck:
            switch activeTransmission!.mode {
            case .writeToSlave: return nil
            case .readFromSlave: return nextAck?.bit
            }
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
