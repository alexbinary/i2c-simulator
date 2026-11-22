
import SwiftUI



class I2CSlaveController: I2CController {
    
    enum TransmissionState {
        case started
        case bitClockLow
        case bitClockHigh
    }
    
    enum TransmissionStatus {
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
        case completedWithoutError
        case completedWithDataWriteNackedBySlave
        case transmissionNotAddressedToSelf
        case transmissionModeNotSupported
        
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
        struct Payload {
            let address: Byte?
            let mode: ReadWrite?
            let transmittedBytes: [Byte]
        }
        let type: `Type`
        let payload: Payload
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
    
    var bytesToBeRead: [Byte] = []
    let nextBytesToBeRead: (() -> [Byte])?
    
    let onTransmissionEnded: ((TransmissionResult)->())?


    init(
        respondsToAddresses: [Byte],
        reportsTransmissionsNotAddressedToSelf: Bool = false,
        acceptWrites: Bool = true,
        acceptReads: Bool = true,
        maxWrites: Int? = nil,
        nextBytesToBeRead: (() -> [Byte])? = nil,
        onTransmissionEnded: ((TransmissionResult)->())? = nil
    ) {
        self.respondsToAddresses = respondsToAddresses
        self.reportsTransmissionsNotAddressedToSelf = reportsTransmissionsNotAddressedToSelf
        self.acceptWrites = acceptWrites
        self.acceptReads = acceptReads
        self.maxWrites = maxWrites
        self.nextBytesToBeRead = nextBytesToBeRead
        self.onTransmissionEnded = onTransmissionEnded
    }


    override func reset(x: CGFloat) {

        lastKnownLineLevels = bus.currentLineLevels
        resetTransmissionState()
        
        releaseSCL()
        releaseSDA()
    }


    override func update(x: CGFloat) {
        
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
            
        case .transmissionNotAddressedToSelf,
             .transmissionModeNotSupported,
             .completedWithoutError,
             .completedWithDataWriteNackedBySlave,
             .transmittingAddressByte:
            releaseSDA()
            
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
            
        case (.ack, .address):
            currentTransmissionStatus = .transmittingDataByte
            currentTransmittedByteIndex = 0
            
        case (.nack, .address):
            if !acceptAddress {
                currentTransmissionStatus = .transmissionNotAddressedToSelf
            } else {
                currentTransmissionStatus = .transmissionModeNotSupported
            }
            transmissionStopped()
            
        case (.ack, .data):
            currentTransmissionStatus = .transmittingDataByte
            currentTransmittedByteIndex += 1
            
        case (.nack, .data):
            switch currentTransmissionMode! {
            case .writeToSlave: currentTransmissionStatus = .completedWithDataWriteNackedBySlave
            case .readFromSlave: currentTransmissionStatus = .completedWithoutError
            }
        }
        
        if currentTransmissionStatus == .transmittingDataByte {
            sourceNextBytesToBeRead()
        }
    }
    
    
    func sourceNextBytesToBeRead() {
        
        if currentTransmittedByteIndex == bytesToBeRead.count {
            var nextBytes = nextBytesToBeRead?() ?? []
            if nextBytes.isEmpty { nextBytes.append(0xff) }
            bytesToBeRead.append(contentsOf: nextBytes)
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
                
            case .transmissionNotAddressedToSelf:
                if reportsTransmissionsNotAddressedToSelf {
                    lastTransmissionResult = makeTransmissionResult(withType: .notAddressedToSelf)
                }
                
            case .transmissionModeNotSupported:
                if reportsTransmissionsNotAddressedToSelf {
                    lastTransmissionResult = makeTransmissionResult(withType: .modeNotSupported)
                }
                
            case .completedWithoutError, .transmittingDataByte:
                lastTransmissionResult = makeTransmissionResult(withType: .success)
                
            case .completedWithDataWriteNackedBySlave:
                lastTransmissionResult = makeTransmissionResult(withType: .dataNack)
            
            case .transmittingAddressByte, .transmittingAddressAck, .transmittingDataAck:
                lastTransmissionResult = makeTransmissionResult(withType: .aborted)
            }
            
            let result = lastTransmissionResult
            resetTransmissionState()
            if let result = result {
                onTransmissionEnded?(result)
            }
        }
    }
    
    
    func makeTransmissionResult(withType type: TransmissionResult.`Type`) -> TransmissionResult {
     
        let payload = TransmissionResult.Payload(
            address: currentTransmissionAddress,
            mode: currentTransmissionMode,
            transmittedBytes: transmittedDataBytes
        )
        return TransmissionResult(type: type, payload: payload)
    }
}
