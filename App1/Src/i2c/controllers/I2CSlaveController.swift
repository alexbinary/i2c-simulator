//
//import SwiftUI
//
//
//
//extension I2CSlaveController{
//    
//    protocol Delegate {
//        func shouldAcceptTransmission(with address: Byte, mode: ReadWrite) -> Bool
//        func shouldContinueHoldingBeforeDataByte(mode: ReadWrite) -> Bool
//        func shouldAckDataByte() -> Bool
//        func nextBytesToBeRead() -> [Byte]
//        func transmissionEnded(withResult: TransmissionResult)
//    }
//}
//
//extension I2CSlaveController.Delegate {
//    func shouldAcceptTransmission(with address: Byte, mode: ReadWrite) -> Bool { false }
//    func shouldContinueHoldingBeforeDataByte(mode: ReadWrite) -> Bool { false }
//    func shouldAckDataByte() -> Bool { true }
//    func nextBytesToBeRead() -> [Byte] { [] }
//    func transmissionEnded(withResult: TransmissionResult) {}
//}
//
//
//class I2CSlaveController: I2CController {
//    
//    enum BusState {
//        case started
//        case clockLow
//        case clockHigh
//    }
//    
//    enum TransmissionStatus {
//        case transmittingAddressByte
//        case transmittingAddressAck
//        case betweenBytes
//        case transmittingDataByte
//        case transmittingDataAck
//        case completed
//        
//        enum ByteOrAck { case byte, ack }
//        var transmittingByteOrAck: ByteOrAck? { (self == .transmittingAddressByte || self == .transmittingDataByte) ? .byte : (self == .transmittingAddressAck || self == .transmittingDataAck) ? .ack : nil }
//        
//        enum AddressOrData { case address, data }
//        var transmittingAddressOrData: AddressOrData? { self == .transmittingAddressByte ? .address : self == .transmittingDataByte ? .data : nil }
//        var currentAckTarget: AddressOrData? { self == .transmittingAddressAck ? .address : self == .transmittingDataAck ? .data : nil }
//    }
//    
//    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)
//    
//    var currentBusState: BusState?
//    var currentTransmissionStatus: TransmissionStatus?
//    var transmissionActive: Bool { currentTransmissionStatus != nil }
//    
//    var holdingClock = false
//    var nextHoldingEndX: CGFloat?
//    var xHoldingWaitBeforeReleasingSCL: CGFloat = 30
//    
//    var lastTransmittedBit: Bit?
//    var lastTransmittedAck: Ack?
//    var lastTransmittedByte: Byte?
//    
//    var transmittedDataBytes: [Byte] = []
//    
//    var currentTransmittedByteReadBits: [Bit] = []
//    var currentTransmittedByteIndex: Int = 0
//    var currentTransmittedByteBitIndex: Int { currentTransmittedByteReadBits.count }
//    
//    var currentTransmissionAddress: Byte?
//    var currentTransmissionRW: ReadWrite?
//    
//    var currentBitToWrite: Bit?
//    var currentAckToWrite: Ack?
//    
//    var currentTransmissionAccepted = false
//    var lastByteAccepted = false
//    
//    var bytesToBeRead: [Byte] = []
//    var delegate: Delegate?
//
//
//    init(delegate: Delegate? = nil) {
//        self.delegate = delegate
//    }
//
//
//    override func reset(x: CGFloat) {
//
//        lastKnownLineLevels = bus.currentLineLevels
//        resetTransmissionState()
//        
//        releaseSCL()
//        releaseSDA()
//    }
//
//
//    override func update(x: CGFloat) {
//        
//        if bus.currentLineLevels != lastKnownLineLevels {
//            
//            if let symbol = detectedSymbol(analysingTransitionFrom: lastKnownLineLevels, to: bus.currentLineLevels) {
//                switch symbol {
//                
//                case .start:
//                    if transmissionActive { transmissionStopped() }
//                    transmissionStarted()
//                    
//                case .stop:
//                    transmissionStopped()
//                
//                case .clockFall:
//                    if currentBusState == .clockHigh { bitClockHighPhaseEnded() }
//                    stretchingPhaseStarted()
//                
//                case .clockRise:
//                    bitClockHighPhaseStarted()
//                }
//            }
//            
//            lastKnownLineLevels = bus.currentLineLevels
//        }
//        
//        if holdingClock && currentTransmissionStatus == .betweenBytes {
//            if !(delegate?.shouldContinueHoldingBeforeDataByte(mode: currentTransmissionRW!) ?? false) {
//                
//                startingNewDataByte()
//                
//                if currentTransmissionRW == .readFromSlave {
//                    nextHoldingEndX = x + xHoldingWaitBeforeReleasingSCL
//                } else {
//                    holdingClock = false
//                }
//            }
//        }
//        
//        if holdingClock && currentTransmissionStatus == .transmittingDataByte, x >= nextHoldingEndX! {
//            holdingClock = false
//        }
//        
//        if holdingClock {
//            pullSCL()
//        } else {
//            releaseSCL()
//        }
//    }
//    
//    
//    func resetTransmissionState() {
//        
//        currentTransmissionStatus = nil
//        currentBusState = nil
//        
//        lastTransmittedBit = nil
//        lastTransmittedAck = nil
//        lastTransmittedByte = nil
//        
//        currentTransmittedByteReadBits = []
//        
//        currentTransmissionAddress = nil
//        currentTransmissionRW = nil
//        currentTransmissionAccepted = false
//        
//        transmittedDataBytes = []
//        lastByteAccepted = false
//        
//        bytesToBeRead = []
//    }
//    
//    
//    func transmissionStarted() {
//        
//        currentTransmissionStatus = .transmittingAddressByte
//        currentBusState = .started
//    }
//    
//    
//    func startingNewDataByte() {
//        
//        if currentTransmissionRW == .readFromSlave {
//            
//            if currentTransmittedByteIndex == bytesToBeRead.count {
//                var nextBytes = delegate?.nextBytesToBeRead() ?? []
//                if nextBytes.isEmpty { nextBytes.append(0xff) }
//                bytesToBeRead.append(contentsOf: nextBytes)
//            }
//        }
//    }
//    
//    
//    func assertBit(_ bit: Bit?) {
//        
//        if bit == .zero {
//            pullSDA()
//        } else {
//            releaseSDA()
//        }
//    }
//    
//    
//    func assertCurrentBit() {
//        
//        assertBit(currentBitToWrite)
//    }
//    
//    
//    func stretchingPhaseStarted() {
//        
//        bitSetupPhaseStarted()
//    }
//    
//    
//    func bitSetupPhaseStarted() {
//        
//        if currentTransmissionStatus == .betweenBytes {
//            currentTransmissionStatus = .transmittingDataByte
//        }
//        
//        switch currentTransmissionStatus! {
//            
//        case .holdingBeforeDataByte_bitSetup, .transmittingDataByte:
//            
//            if currentTransmissionRW == .readFromSlave {
//                let byte = bytesToBeRead[currentTransmittedByteIndex]
//                currentBitToWrite = byte.bit(atIndex: currentTransmittedByteBitIndex)
//            }
//            
//        case .transmittingAddressAck:
//            currentBitToWrite = Ack(ackIf: currentTransmissionAccepted).bit
//            
//        case .transmittingDataAck:
//            if currentTransmissionRW == .writeToSlave {
//                currentAckToWrite = Ack(ackIf: lastByteAccepted)
//            }
//            
//        default:
//            break
//        }
//        
//        assertCurrentBit()
//        currentBusState = .clockLow
//    }
//    
//    
//    func bitClockHighPhaseStarted() {
//        
//        assertCurrentBit()
//        currentBusState = .clockHigh
//    }
//    
//    
//    func bitClockHighPhaseActive() {
//        
//        assertCurrentBit()
//        lastTransmittedBit = bus.lineSDA.currentLevel.bit
//    }
//    
//    
//    func bitClockHighPhaseEnded() {
//        
//        transmittedBit()
//        currentBusState = .started
//    }
//    
//    
//    func transmittedBit() {
//        
//        switch currentTransmissionStatus!.transmittingByteOrAck {
//            
//        case .byte:
//            currentTransmittedByteReadBits.append(lastTransmittedBit!)
//            if currentTransmittedByteReadBits.count == 8 {
//                
//                lastTransmittedByte = Byte(from: currentTransmittedByteReadBits)
//                currentTransmittedByteReadBits = []
//                transmittedByte()
//            }
//            
//        case .ack:
//            lastTransmittedAck = Ack(from: lastTransmittedBit!)
//            transmittedAck()
//            
//        case .none:
//            break
//        }
//    }
//    
//    
//    func transmittedByte() {
//        
//        currentAckToWrite = nil
//        
//        switch currentTransmissionStatus!.transmittingAddressOrData {
//
//        case .address:
//            
//            let addressByte = lastTransmittedByte!
//            let address = (addressByte >> 1)
//            let rwBit = Bit(addressByte & 1)
//            let rw = ReadWrite(from: rwBit)
//            
//            currentTransmissionAddress = address
//            currentTransmissionRW = rw
//            currentTransmissionAccepted = delegate?.shouldAcceptTransmission(with: address, mode: rw) ?? false
//            
//            currentTransmissionStatus = .transmittingAddressAck
//            
//        case .data:
//            
//            transmittedDataBytes.append(lastTransmittedByte!)
//            
//            if currentTransmissionRW == .writeToSlave {
//                lastByteAccepted = delegate?.shouldAckDataByte() ?? false
//            }
//            currentTransmissionStatus = .transmittingDataAck
//            
//        case .none:
//            break
//        }
//    }
//    
//    
//    func transmittedAck() {
//        
//        let ackSentBySelf = currentTransmissionStatus!.currentAckTarget! == .address || currentTransmissionRW == .writeToSlave
//        let ackValue = ackSentBySelf ? currentAckToWrite! : lastTransmittedAck!
//        
//        switch (ackValue, currentTransmissionStatus!.currentAckTarget!) {
//            
//        case (.ack, .address),
//             (.nack, .address):
//            currentTransmissionStatus = .holdingBeforeDataByte
//            currentTransmittedByteIndex = 0
//            
//        case (.ack, .data):
//            currentTransmissionStatus = .holdingBeforeDataByte
//            currentTransmittedByteIndex += 1
//            
//        case (.nack, .data):
//            currentTransmissionStatus = .completed
//        }
//    }
//    
//    
//    func transmissionStopped() {
//        
//        let result = transmissionResult()
//        resetTransmissionState()
//        if let result = result {
//            delegate?.transmissionEnded(withResult: result)
//        }
//    }
//    
//    
//    func transmissionResult() -> TransmissionResult? {
//        
//        let normalStop = (currentTransmissionStatus == .completed && (currentTransmissionRW == .readFromSlave || lastByteAccepted)) || (currentTransmissionRW == .writeToSlave && currentTransmissionStatus == .transmittingDataByte)
//        if normalStop {
//            if currentTransmissionAccepted {
//                return makeTransmissionResult(withType: .success)
//            } else {
//                return makeTransmissionResult(withType: .transmissionRefused)
//            }
//        }
//        
//        if !lastByteAccepted {
//            return makeTransmissionResult(withType: .dataNack)
//        }
//        
//        return makeTransmissionResult(withType: .aborted)
//    }
//    
//    
//    func makeTransmissionResult(withType type: TransmissionResult.`Type`) -> TransmissionResult {
//     
//        return TransmissionResult(
//            type: type,
//            address: currentTransmissionAddress,
//            mode: currentTransmissionRW,
//            transmittedBytes: transmittedDataBytes
//        )
//    }
//}
