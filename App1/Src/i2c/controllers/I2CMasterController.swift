
import SwiftUI



extension I2CMasterController{
    
    protocol Delegate {
        func onTransmissionEnded(result: TransmissionResult)
    }
}

extension I2CMasterController.Delegate {
    func onTransmissionEnded(result: I2CSlaveController.TransmissionResult) {}
}


class I2CMasterController: I2CController {
    
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
    
    enum TransmissionBitState {
        case holdingBeforeNextBit
        case readyForNextBit
        case bitSetup
        case bitClock
    }
    
    enum TransmissionControlState {
        case preparingStart_gettingSCLLow
        case preparingStart_gettingSDAHigh
        case preparingStart_gettingSCLHigh
        case start_pullingSDA
        case bitSetup_gettingSCLLow
        case bitSetup_assertingSDA
        case bitClock_gettingSCLHigh
        case bitClock_sendingBit
        case preparingStop_gettingSCLLow
        case preparingStop_gettingSDALow
        case preparingStop_gettingSCLHigh
        case stop_releasingSDA
    }
    
    struct TransmissionResult {
        enum `Type` {
            case success
            case dataNack
            case aborted
            case transmissionRefused
        }
        let type: `Type`
        let address: Byte?
        let mode: ReadWrite?
        let transmittedBytes: [Byte]
        
        var isSuccess: Bool { return type == .success }
        
        var isRead: Bool { return mode == .readFromSlave }
        var isWrite: Bool { return mode == .writeToSlave }
        
        var isWriteSuccess: Bool { return type == .success && mode == .writeToSlave }
        var isReadSuccess: Bool { return type == .success && mode == .readFromSlave }
    }
    
    var currentTransmissionStatus: TransmissionStatus?
    var currentTransmissionBitState: TransmissionBitState?
    var currentTransmissionControlState: TransmissionControlState?
    
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
    
    var currentTransmissionAddress: Byte?
    var currentTransmissionMode: ReadWrite?
    
    var delegate: Delegate?
    
    
    init(delegate: Delegate? = nil) {
        
        self.delegate = delegate
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append((x: x, transmission: transmission))
    }
    
    
    override func reset(x: CGFloat) {
    
        lastKnownLineLevels = bus.currentLineLevels
        
        clearActiveTransmission()
        
        releaseSCL()
        releaseSDA()
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
        
        updateHoldingState(x: x)
        
        while true {
            let previousState = currentTransmissionBitState
            
            if currentTransmissionBitState != nil {
                switch currentTransmissionBitState! {
                    
                case .holdingBeforeNextBit:
                    break
                    
                case .readyForNextBit:
                    if bus.lineSCL.isLow {
                        bitSetupPhaseStarted()
                    }
                    
                case .bitSetup:
                    if bus.lineSCL.isHigh {
                        bitClockHighPhaseStarted()
                    }
                    
                case .bitClock:
                    if bus.lineSCL.isHigh {
                        bitClockHighPhaseActive()
                    } else {
                        bitClockHighPhaseEnded()
                    }
                }
            }
            
            if currentTransmissionBitState != previousState {
                continue
            } else {
                break
            }
        }
        
        if activeTransmission != nil {
            updateTransmissionControlState(x: x)
        }
        
        updateBusControls(x: x)
    }
    
    
    func updateHoldingState(x: CGFloat) {
        
        if currentTransmissionBitState == .holdingBeforeNextBit {
        
            currentTransmissionBitState = .readyForNextBit
        }
    }
    
    
    func updateTransmissionControlState(x: CGFloat) {
        
        while true {
            
            let previousState = currentTransmissionControlState
            
            switch currentTransmissionControlState! {
                
            case .preparingStart_gettingSCLLow,
                 .preparingStart_gettingSDAHigh,
                 .preparingStart_gettingSCLHigh:
                updateControlStateForStart()
                
            case .start_pullingSDA:
                if bus.currentLineLevels == (SCL: .high, SDA: .low) {
                    initiateAddress()
                } else {
                    updateControlStateForStart()
                }
                
            case .bitSetup_gettingSCLLow:
                if bus.lineSCL.isLow {
                    currentTransmissionControlState = .bitSetup_assertingSDA
                    lastBitClockLowStartX = x
                }
                
            case .bitSetup_assertingSDA:
                if nextBitToWrite == nil || bus.lineSDA.currentLevel.bit == nextBitToWrite {
                    currentTransmissionControlState = .bitClock_gettingSCLHigh
                }
                
            case .bitClock_gettingSCLHigh:
                if bus.lineSCL.isHigh {
                    currentTransmissionControlState = .bitClock_sendingBit
                    lastBitClockHighStartX = x
                }
                
            case .bitClock_sendingBit:
                if bus.lineSCL.isHigh {
//                    bitClockHighPhaseActive()
                } else {
//                    bitClockHighPhaseEnded()
                    lastBitClockLowStartX = x
                }
                
            case .preparingStop_gettingSCLLow,
                 .preparingStop_gettingSDALow,
                 .preparingStop_gettingSCLHigh:
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
                
            case .preparingStart_gettingSCLLow:
                pullSCL()
                
            case .preparingStart_gettingSCLHigh:
                releaseSCL()
            
            case .preparingStart_gettingSDAHigh:
                releaseSDA()
            
            case .start_pullingSDA:
                if !busBusy,
                   waited(xWaitAfterStop, relativeTo: lastStopX, x: x),
                   waited(xWaitBeforeStart, relativeTo: lastIdleReachedX, x: x) {
                    pullSDA()
                }
                
            case .bitSetup_gettingSCLLow:
                pullSCL()
                
            case .bitSetup_assertingSDA:
                assertWriteBit()
                
            case .bitClock_gettingSCLHigh:
                assertWriteBit()
                if waited(xBitClockLowDuration, relativeTo: lastBitClockLowStartX, x: x) {
                    releaseSCL()
                }
                
            case .bitClock_sendingBit:
                assertWriteBit()
                if waited(xBitClockHighDuration, relativeTo: lastBitClockHighStartX, x: x) {
                    pullSCL()
                }
                
            case .preparingStop_gettingSCLLow:
                pullSCL()
                
            case .preparingStop_gettingSCLHigh:
                releaseSCL()
            
            case .preparingStop_gettingSDALow:
                pullSDA()
            
            case .stop_releasingSDA:
                releaseSDA()
                
            case .none:
                releaseSCL()
                releaseSDA()
            }
        }
    }
    
    
    func assertWriteBit() {
        
        if nextBitToWrite == .zero {
            pullSDA()
        } else {
            releaseSDA()
        }
    }


    func clearActiveTransmission() {
        
        activeTransmission = nil
        
        currentTransmissionControlState = nil
        currentTransmissionStatus = nil
        
        lastTransmittedBit = nil
        lastTransmittedAck = nil
        
        lastTransmittedByte = nil
        transmittedDataBytes = []
        currentTransmittedByteReadBits = []
    }
    
    
    func startActiveTransmission(x: CGFloat) {
        
        currentTransmissionStatus = .starting
        holdingBus = false
        
        initiateStart()
    }
    
    
    var nextControlStateForStart: TransmissionControlState {
        
        switch bus.currentLineLevels {
        case (SCL: .high, SDA: .high): return .start_pullingSDA
        case (SCL: .high, SDA: .low): return .preparingStart_gettingSCLLow
        case (SCL: .low, SDA: .high): return .preparingStart_gettingSCLHigh
        case (SCL: .low, SDA: .low): return .preparingStart_gettingSDAHigh
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
            return .bitSetup_gettingSCLLow
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
        case (SCL: .high, SDA: .high): return .preparingStop_gettingSCLLow
        case (SCL: .low, SDA: .high): return .preparingStop_gettingSDALow
        case (SCL: .low, SDA: .low): return .preparingStop_gettingSCLHigh
        }
    }
    
    func updateControlStateForStop() {
        
        currentTransmissionControlState = nextControlStateForStop
    }
    
    func initiateStop() {
        
        updateControlStateForStop()
    }
    
    
    func bitSetupPhaseStarted() {
    }
    
    
    func bitClockHighPhaseStarted() {
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
            let stillHaveBytesToSend = transmittedDataBytes.count < activeTransmission!.numBytes
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
        }
    }
    
    
    func transmissionStopped() {
        
        let result = transmissionResult()
        clearActiveTransmission()
        if let result = result {
            delegate?.onTransmissionEnded(result: result)
        }
    }
    
    
    func transmissionResult() -> TransmissionResult? {
        
        if let status = currentTransmissionStatus {
            switch status {
                
            case .completedWithoutError:
                return makeTransmissionResult(withType: .success)
                
            case .completedWithAddressNacked:
                return makeTransmissionResult(withType: .transmissionRefused)
                
            case .completedWithDataNackedBySlave:
                return makeTransmissionResult(withType: .dataNack)
                
            case .starting,
                    .transmittingAddressByte,
                    .transmittingAddressAck,
                    .transmittingDataByte,
                    .transmittingDataAck:
                return makeTransmissionResult(withType: .aborted)
            }
        }
        
        return nil
    }
    
    
    func makeTransmissionResult(withType type: TransmissionResult.`Type`) -> TransmissionResult {
        
        return TransmissionResult(
            type: type,
            address: activeTransmission!.address,
            mode: activeTransmission!.mode,
            transmittedBytes: transmittedDataBytes
        )
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
            return currentAddressBitToWrite
        
        case .transmittingDataByte:
            switch activeTransmission!.mode {
            case .writeToSlave: return currentDataBitToWrite
            case .readFromSlave: return nil
            }
        
        case .transmittingDataAck:
            switch activeTransmission!.mode {
            case .writeToSlave: return nil
            case .readFromSlave: return currentAck!.bit
            }
        }
    }
    
    
    var currentAck: Ack? {
        
        if currentTransmissionStatus == .transmittingDataAck, activeTransmission!.isReadFromSlave {
            return Ack(ackIf: (currentTransmittedByteIndex+1) < activeTransmission!.numBytes)
        }
        return nil
    }


    var currentAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }


    var currentDataBitToWrite: Bit {

        let byte = activeTransmission!.bytes[currentTransmittedByteIndex]
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }
}
