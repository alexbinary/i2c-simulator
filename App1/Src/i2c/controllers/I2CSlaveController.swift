
import SwiftUI



extension I2CSlaveController{
    
    protocol Delegate {
        func nextBytesToBeRead() -> [Byte]
        func shouldContinueHoldingBeforeDataByte(mode: ReadWrite) -> Bool
        func onTransmissionEnded(result: TransmissionResult)
    }
}

extension I2CSlaveController.Delegate {
    
    func nextBytesToBeRead() -> [Byte] { [] }
    func shouldContinueHoldingBeforeDataByte(mode: ReadWrite) -> Bool { false }
    func onTransmissionEnded(result: I2CSlaveController.TransmissionResult) {}
}


class I2CSlaveController: I2CController {
    
    enum TransmissionState {
        case started
        case bitClockLow
        case bitClockHigh
    }
    
    enum TransmissionStatus {
        case transmittingAddressByte
        case transmittingAddressAck
        case holdingBeforeDataByte
        case transmittingDataByte
        case transmittingDataAck
        case completedWithoutError
        case completedWithDataWriteNackedBySlave
        
        enum ByteOrAck { case byte, ack }
        var transmittingByteOrAck: ByteOrAck? { (self == .transmittingAddressByte || self == .transmittingDataByte) ? .byte : (self == .transmittingAddressAck || self == .transmittingDataAck) ? .ack : nil }
        
        enum AddressOrData { case address, data }
        var transmittingAddressOrData: AddressOrData? { self == .transmittingAddressByte ? .address : self == .transmittingDataByte ? .data : nil }
        var currentAckTarget: AddressOrData? { self == .transmittingAddressAck ? .address : self == .transmittingDataAck ? .data : nil }
    }
    
    struct TransmissionResult {
        enum `Type` {
            case success
            case dataNack
            case aborted
            case notAddressedToSelf
            case modeNotSupported
        }
        let type: `Type`
        let address: Byte?
        let mode: ReadWrite?
        let transmittedBytes: [Byte]
        
        var isWriteSuccess: Bool { return type == .success && mode == .writeToSlave }
        var isReadSuccess: Bool { return type == .success && mode == .readFromSlave }
    }
    
    var currentTransmissionState: TransmissionState?
    var currentTransmissionStatus: TransmissionStatus?
    var lastTransmissionResult: TransmissionResult?
    
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)
    
    var lastTransmittedBit: Bit?
    var lastTransmittedAck: Ack?
    
    var lastTransmittedByte: Byte?
    var transmittedDataBytes: [Byte] = []
    
    var currentTransmittedByteReadBits: [Bit] = []
    var currentTransmittedByteIndex: Int = 0
    var currentTransmittedByteBitIndex: Int { currentTransmittedByteReadBits.count }
    
    var currentTransmissionAddress: Byte?
    var currentTransmissionMode: ReadWrite?
    
    let respondsToAddresses: [Byte]
    let reportsTransmissionsNotAddressedToSelf: Bool
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?
    
    var acceptAddress: Bool { currentTransmissionAddress != nil && self.respondsToAddresses.contains(currentTransmissionAddress!) }
    var acceptRW: Bool { currentTransmissionMode == .writeToSlave && acceptWrites || currentTransmissionMode == .readFromSlave && acceptReads }
    var acceptTransmission: Bool { acceptAddress && acceptRW }
    
    var bytesToBeRead: [Byte] = []
    var delegate: Delegate?


    init(
        respondsToAddresses: [Byte],
        reportsTransmissionsNotAddressedToSelf: Bool = false,
        acceptWrites: Bool = true,
        acceptReads: Bool = true,
        maxWrites: Int? = nil,
        delegate: Delegate? = nil
    ) {
        self.respondsToAddresses = respondsToAddresses
        self.reportsTransmissionsNotAddressedToSelf = reportsTransmissionsNotAddressedToSelf
        self.acceptWrites = acceptWrites
        self.acceptReads = acceptReads
        self.maxWrites = maxWrites
        self.delegate = delegate
    }


    override func reset(x: CGFloat) {

        lastKnownLineLevels = bus.currentLineLevels
        resetTransmissionState()
        
        releaseSCL()
        releaseSDA()
    }


    override func update(x: CGFloat) {
        
        if currentTransmissionStatus == .holdingBeforeDataByte {
            
            if !(delegate?.shouldContinueHoldingBeforeDataByte(mode: currentTransmissionMode!) ?? false) {
                
                currentTransmissionStatus = .transmittingDataByte
                
                if currentTransmissionMode == .readFromSlave, currentTransmittedByteIndex == bytesToBeRead.count {
                    var nextBytes = delegate?.nextBytesToBeRead() ?? []
                    if nextBytes.isEmpty { nextBytes.append(0xff) }
                    bytesToBeRead.append(contentsOf: nextBytes)
                }
                
                bitSetupPhaseStarted()
            }
        }
        
        if bus.currentLineLevels != lastKnownLineLevels {
            
            if detectedStartCondition(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                
                transmissionStopped()
                transmissionStarted()
            }
            if detectedStopCondition(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
                
                transmissionStopped()
            }
            
            while true {
                let previousState = currentTransmissionState
                
                if currentTransmissionState != nil {
                    switch currentTransmissionState! {
                        
                    case .started:
                        if bus.lineSCL.isLow {
                            bitSetupPhaseStarted()
                        }
                        
                    case .bitClockLow:
                        if bus.lineSCL.isHigh {
                            bitClockHighPhaseStarted()
                        }
                        
                    case .bitClockHigh:
                        if bus.lineSCL.isHigh {
                            bitClockHighPhaseActive()
                        } else {
                            bitClockHighPhaseEnded()
                        }
                    }
                }
                
                if currentTransmissionState != previousState {
                    continue
                } else {
                    break
                }
            }
            
            lastKnownLineLevels = bus.currentLineLevels
        }
        
        if currentTransmissionStatus == .holdingBeforeDataByte && acceptTransmission {
            pullSCL()
        } else {
            releaseSCL()
        }
    }
    
    
    func resetTransmissionState() {
        
        currentTransmissionState = nil
        currentTransmissionStatus = nil
        lastTransmissionResult = nil
        lastTransmittedBit = nil
        lastTransmittedAck = nil
        lastTransmittedByte = nil
        transmittedDataBytes = []
        currentTransmittedByteReadBits = []
        currentTransmissionAddress = nil
        currentTransmissionMode = nil
        bytesToBeRead = []
    }
    
    
    func transmissionStarted() {
        
        currentTransmissionState = .started
        currentTransmissionStatus = .transmittingAddressByte
    }
    
    
    func bitSetupPhaseStarted() {
        
        currentTransmissionState = .bitClockLow
         
        switch currentTransmissionStatus! {
            
        case .completedWithoutError,
             .completedWithDataWriteNackedBySlave,
             .transmittingAddressByte:
            releaseSDA()
            
        case .holdingBeforeDataByte:
            break
            
        case .transmittingDataByte:
            if currentTransmissionMode == .readFromSlave && currentDataBitToWrite == .zero {
                pullSDA()
            } else {
                releaseSDA()
            }
        
        case .transmittingAddressAck,
             .transmittingDataAck:
            if currentAck == .ack {
                pullSDA()
            } else {
                releaseSDA()
            }
        }
    }
    
    
    func bitClockHighPhaseStarted() {
        
        currentTransmissionState = .bitClockHigh
    }
    
    
    func bitClockHighPhaseActive() {
        
        lastTransmittedBit = bus.lineSDA.currentLevel.bit
    }
    
    
    func bitClockHighPhaseEnded() {
        
        currentTransmissionState = .started
        releaseSDA()
        
        switch currentTransmissionStatus!.transmittingByteOrAck {

        case .byte:
            currentTransmittedByteReadBits.append(lastTransmittedBit!)
            if currentTransmittedByteReadBits.count == 8 {
                
                lastTransmittedByte = Byte(from: currentTransmittedByteReadBits)
                currentTransmittedByteReadBits = []
                transmittedByte()
            }
            
        case .ack:
            lastTransmittedAck = Ack(from: lastTransmittedBit!)
            transmittedAck()
            
        case .none:
            break
        }
    }
    
    
    func transmittedByte() {
        
        switch currentTransmissionStatus!.transmittingAddressOrData {

        case .address:
            
            let addressByte = lastTransmittedByte!
            let address = (addressByte >> 1)
            let rwBit = Bit(addressByte & 1)
            let rw = ReadWrite(from: rwBit)
            
            currentTransmissionAddress = address
            currentTransmissionMode = rw
            
            currentTransmissionStatus = .transmittingAddressAck
            
        case .data:
            
            transmittedDataBytes.append(lastTransmittedByte!)
            currentTransmissionStatus = .transmittingDataAck
            
        case .none:
            break
        }
    }
    
    
    func transmittedAck() {
        
        let ackSentBySelf = currentTransmissionStatus!.currentAckTarget! == .address || currentTransmissionMode == .writeToSlave
        let ackValue = ackSentBySelf ? currentAck! : lastTransmittedAck!
        
        switch (ackValue, currentTransmissionStatus!.currentAckTarget!) {
            
        case (.ack, .address),
             (.nack, .address):
            currentTransmissionStatus = .holdingBeforeDataByte
            currentTransmittedByteIndex = 0
            if ackValue == .nack && !reportsTransmissionsNotAddressedToSelf {
                transmissionStopped()
            }
            
        case (.ack, .data):
            currentTransmissionStatus = .holdingBeforeDataByte
            currentTransmittedByteIndex += 1
            
        case (.nack, .data):
            switch currentTransmissionMode! {
            case .writeToSlave: currentTransmissionStatus = .completedWithDataWriteNackedBySlave
            case .readFromSlave: currentTransmissionStatus = .completedWithoutError
            }
        }
    }
    
    
    var currentAck: Ack? {
        
        switch currentTransmissionStatus {
            
        case .transmittingAddressAck:
            if acceptAddress && acceptRW {
                return .ack
            } else {
                return .nack
            }
            
        case .transmittingDataAck:
            if currentTransmissionMode == .writeToSlave {
                return Ack(ackIf: maxWrites == nil || transmittedDataBytes.count < maxWrites!)
            }
            
        default:
            break
        }
        
        return nil
    }
    
    
    var currentDataBitToWrite: Bit {
        
        let byte = bytesToBeRead[currentTransmittedByteIndex]
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }
    
    
    func transmissionStopped() {
        
        if let status = currentTransmissionStatus {
            switch status {
                
            case .completedWithoutError, .transmittingDataByte, .holdingBeforeDataByte:
                if acceptAddress && acceptRW {
                    lastTransmissionResult = makeTransmissionResult(withType: .success)
                } else if reportsTransmissionsNotAddressedToSelf {
                    if !acceptAddress {
                        lastTransmissionResult = makeTransmissionResult(withType: .notAddressedToSelf)
                    } else {
                        lastTransmissionResult = makeTransmissionResult(withType: .modeNotSupported)
                    }
                }
                
            case .completedWithDataWriteNackedBySlave:
                lastTransmissionResult = makeTransmissionResult(withType: .dataNack)
            
            default:
                lastTransmissionResult = makeTransmissionResult(withType: .aborted)
            }
            
            let result = lastTransmissionResult
            resetTransmissionState()
            if let result = result {
                delegate?.onTransmissionEnded(result: result)
            }
        }
    }
    
    
    func makeTransmissionResult(withType type: TransmissionResult.`Type`) -> TransmissionResult {
     
        return TransmissionResult(
            type: type,
            address: currentTransmissionAddress,
            mode: currentTransmissionMode,
            transmittedBytes: transmittedDataBytes
        )
    }
}
