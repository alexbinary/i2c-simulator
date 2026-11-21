
import SwiftUI



class I2CMasterController: I2CController {
    
    enum TransmissionControlState {
        case startSetup_assertingSCLLow
        case startSetup_assertingSDAHigh
        case startSetup_assertingSCLHigh
        case start_pullingSDA
        case bitSetup_assertingSCLLow
        case bitSetup_assertingSDA
        case bitClock_assertingSCLHigh
        case bitClock_sendingBit
        case stopSetup_assertingSCLLow
        case stopSetup_assertingSDALow
        case stopSetup_assertingSCLHigh
        case stop_releasingSDA
    }
    
    enum TransmissionStatus {
        case starting
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
        case completedWithoutError
        case completedWithDataNackedBySlave
        case completedWithAddressNacked
        
        enum ByteOrAck { case byte, ack }
        var transmittingByteOrAck: ByteOrAck? { (self == .transmittingAddressByte || self == .transmittingDataByte) ? .byte : (self == .transmittingAddressAck || self == .transmittingDataAck) ? .ack : nil  }
        
        enum AddressOrData { case address, data }
        var transmittingAddressOrData: AddressOrData? { self == .transmittingAddressByte ? .address : self == .transmittingDataByte ? .data : nil }
        var currentAckTarget: AddressOrData? { self == .transmittingAddressAck ? .address : self == .transmittingDataAck ? .data : nil }
    }
    
    enum TransmissionResult {
        case addressNack
        case success(transmittedBytes: [Byte])
        case dataNack(transmittedBytes: [Byte])
        case aborted(transmittedBytes: [Byte])
    }
    
    var currentTransmissionControlState: TransmissionControlState?
    var currentTransmissionStatus: TransmissionStatus?
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
    
    var currentAck: Ack?
    
    let onTransmissionEnded: ((TransmissionResult)->())?
    
    
    init(onTransmissionEnded: ((TransmissionResult)->())?) {
        
        self.onTransmissionEnded = onTransmissionEnded
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append((x: x, transmission: transmission))
    }
    
    
    override func reset(x: CGFloat) {
    
        lastKnownLineLevels = bus.currentLineLevels
        
        clearActiveTransmission()
        
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
                
                transmissionStopped()
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
        }
        
        updateBusControls(x: x)
    }
    
    
    func updateTransmissionControlState(x: CGFloat) {
        
        while true {
            
            let previousState = currentTransmissionControlState
            
            switch currentTransmissionControlState! {
                
            case .startSetup_assertingSCLLow,
                 .startSetup_assertingSDAHigh,
                 .startSetup_assertingSCLHigh:
                updateControlStateForStart()
                
            case .start_pullingSDA:
                if bus.currentLineLevels == (SCL: .high, SDA: .low) {
                    initiateAddress()
                } else {
                    updateControlStateForStart()
                }
                
            case .bitSetup_assertingSCLLow:
                if bus.lineSCL.isLow {
                    currentTransmissionControlState = .bitSetup_assertingSDA
                    lastBitClockLowStartX = x
                }
                
            case .bitSetup_assertingSDA:
                if nextBitToWrite == nil || bus.lineSDA.currentLevel.bit == nextBitToWrite {
                    currentTransmissionControlState = .bitClock_assertingSCLHigh
                }
                
            case .bitClock_assertingSCLHigh:
                if bus.lineSCL.isHigh {
                    currentTransmissionControlState = .bitClock_sendingBit
                    lastBitClockHighStartX = x
                }
                
            case .bitClock_sendingBit:
                if bus.lineSCL.isHigh {
                    bitClockHighPhaseActive()
                } else {
                    bitClockHighPhaseEnded()
                    lastBitClockLowStartX = x
                }
                
            case .stopSetup_assertingSCLLow,
                 .stopSetup_assertingSDALow,
                 .stopSetup_assertingSCLHigh:
                updateControlStateForStop()
                
            case .stop_releasingSDA:
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
    
    
    func updateBusControls(x: CGFloat) {
        
        if waited(xWaitAfterLineChange, relativeTo: lastLineChangeX, x: x) {
            
            switch currentTransmissionControlState {
                
            case .startSetup_assertingSCLLow:
                self.pullingSCL = true
                
            case .startSetup_assertingSCLHigh:
                self.pullingSCL = false
            
            case .startSetup_assertingSDAHigh:
                self.pullingSDA = false
            
            case .start_pullingSDA:
                if !busBusy,
                   waited(xWaitAfterStop, relativeTo: lastStopX, x: x),
                   waited(xWaitBeforeStart, relativeTo: lastIdleReachedX, x: x) {
                    self.pullingSDA = true
                }
                
            case .bitSetup_assertingSCLLow:
                self.pullingSCL = true
                
            case .bitSetup_assertingSDA:
                assertWriteBit()
                
            case .bitClock_assertingSCLHigh:
                assertWriteBit()
                if waited(xBitClockLowDuration, relativeTo: lastBitClockLowStartX, x: x) {
                    self.pullingSCL = false
                }
                
            case .bitClock_sendingBit:
                assertWriteBit()
                if waited(xBitClockHighDuration, relativeTo: lastBitClockHighStartX, x: x) {
                    self.pullingSCL = true
                }
                
            case .stopSetup_assertingSCLLow:
                self.pullingSCL = true
                
            case .stopSetup_assertingSCLHigh:
                self.pullingSCL = false
            
            case .stopSetup_assertingSDALow:
                self.pullingSDA = true
            
            case .stop_releasingSDA:
                self.pullingSDA = false
                
            case .none:
                self.pullingSCL = false
                self.pullingSDA = false
            }
        }
    }
    
    
    func assertWriteBit() {
        
        self.pullingSDA = nextBitToWrite == .zero
    }


    func clearActiveTransmission() {
        
        activeTransmission = nil
        
        currentTransmissionControlState = nil
        currentTransmissionStatus = nil
        lastTransmissionResult = nil
        
        lastTransmittedBit = nil
        lastTransmittedAck = nil
        
        lastTransmittedByte = nil
        transmittedDataBytes = []
        currentTransmittedByteReadBits = []

        currentAck = nil
    }
    
    
    func startActiveTransmission(x: CGFloat) {
        
        currentTransmissionStatus = .starting
        lastTransmissionResult = nil
        holdingBus = false
        
        initiateStart()
    }
    
    
    var nextControlStateForStart: TransmissionControlState {
        
        switch bus.currentLineLevels {
        case (SCL: .high, SDA: .high): return .start_pullingSDA
        case (SCL: .high, SDA: .low): return .startSetup_assertingSCLLow
        case (SCL: .low, SDA: .high): return .startSetup_assertingSCLHigh
        case (SCL: .low, SDA: .low): return .startSetup_assertingSDAHigh
        }
    }
    
    func updateControlStateForStart() {
        
        currentTransmissionControlState = nextControlStateForStart
    }
    
    func initiateStart() {
        
        updateControlStateForStart()
    }
    
    
    func initiateAddress() {
        
        currentTransmissionStatus = .transmittingAddressByte
        initiateNextBit()
    }
    
    
    func initiateNextDataByte() {
        
        currentTransmissionStatus = .transmittingDataByte
        initiateNextBit()
    }
    
    
    var nextControlStateForBit: TransmissionControlState {
        
        if bus.lineSCL.isHigh {
            return .bitSetup_assertingSCLLow
        } else {
            return .bitSetup_assertingSDA
        }
    }
    
    func initiateNextBit() {
        
        currentTransmissionControlState = nextControlStateForBit
    }
    
    
    var nextControlStateForStop: TransmissionControlState {
        
        switch bus.currentLineLevels {
        case (SCL: .high, SDA: .low): return .stop_releasingSDA
        case (SCL: .high, SDA: .high): return .stopSetup_assertingSCLLow
        case (SCL: .low, SDA: .high): return .stopSetup_assertingSDALow
        case (SCL: .low, SDA: .low): return .stopSetup_assertingSCLHigh
        }
    }
    
    func updateControlStateForStop() {
        
        currentTransmissionControlState = nextControlStateForStop
    }
    
    func initiateStop() {
        
        updateControlStateForStop()
    }
    
    
    func bitClockHighPhaseActive() {
        
        lastTransmittedBit = bus.lineSDA.currentLevel.bit
    }
    
    
    func bitClockHighPhaseEnded() {
        
        switch currentTransmissionStatus!.transmittingByteOrAck {
        
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
            
        case .none:
            break
        }
    }
    
    
    func transmittedAck() {
        
        let ackSentBySelf = currentTransmissionStatus!.currentAckTarget! == .data && activeTransmission!.mode == .readFromSlave
        let ackValue = ackSentBySelf ? currentAck! : lastTransmittedAck!
        
        switch ackValue {
        case .ack:
            let stillHaveBytesToSend = (currentTransmittedByteIndex+1) < activeTransmission!.numBytes
            switch stillHaveBytesToSend {
            case true:
                switch currentTransmissionStatus!.currentAckTarget! {
                case .address: currentTransmittedByteIndex = 0
                case .data: currentTransmittedByteIndex += 1
                }
                initiateNextDataByte()
                
            case false:
                currentTransmissionStatus = .completedWithoutError
                initiateStop()
            }
            
        case .nack:
            switch currentTransmissionStatus!.currentAckTarget! {
            case .address:
                currentTransmissionStatus = .completedWithAddressNacked
            case .data:
                switch activeTransmission!.mode {
                case .writeToSlave: currentTransmissionStatus = .completedWithDataNackedBySlave
                case .readFromSlave: currentTransmissionStatus = .completedWithoutError
                }
            }
            initiateStop()
        }
    }
    
    
    func transmittedDataByte() {
        
        switch currentTransmissionStatus!.transmittingAddressOrData! {
        case .address:
            currentTransmissionStatus = .transmittingAddressAck
        case .data:
            transmittedDataBytes.append(lastTransmittedByte!)
            currentTransmissionStatus = .transmittingDataAck
            if activeTransmission!.isReadFromSlave {
                currentAck = Ack(ackIf: (currentTransmittedByteIndex+1) < activeTransmission!.numBytes)
            } else {
                currentAck = nil
            }
        }
    }
    
    
    func transmissionStopped() {
        
        if let status = currentTransmissionStatus {
            switch status {
                
            case .completedWithoutError:
                lastTransmissionResult = .success(transmittedBytes: transmittedDataBytes)
            
            case .completedWithAddressNacked:
                lastTransmissionResult = .addressNack
            
            case .completedWithDataNackedBySlave:
                lastTransmissionResult = .dataNack(transmittedBytes: transmittedDataBytes)
            
            case .starting,
                 .transmittingAddressByte,
                 .transmittingAddressAck,
                 .transmittingDataByte,
                 .transmittingDataAck:
                lastTransmissionResult = .aborted(transmittedBytes: transmittedDataBytes)
            }
            
            let result = lastTransmissionResult
            clearActiveTransmission()
            if let result = result {
                onTransmissionEnded?(result)
            }
        }
    }
     
    
    var nextBitToWrite: Bit? {

        switch currentTransmissionStatus! {
        
        case .starting,
             .completedWithoutError,
             .completedWithDataNackedBySlave,
             .completedWithAddressNacked,
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
            case .readFromSlave: return currentAck!.bit
            }
        }
    }


    var nextAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }


    var nextDataBitToWrite: Bit {

        let byte = activeTransmission!.bytes[currentTransmittedByteIndex]
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }
}
