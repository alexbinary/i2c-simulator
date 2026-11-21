
import SwiftUI



class I2CSlaveController: I2CController {
    
    enum TransmissionState {
        case waitingStart
        case started
        case bitClockLow
        case bitClockHigh
        case stopped
    }
    
    enum TransmissionStatus {
        
        enum Phase { case byte, ack }
        
        case waitingStart
        case transmittingAddressByte
        case transmittingAddressAck
        case transmittingDataByte
        case transmittingDataAck
        case completed
        case addressNacked
        
        var isTransmittingAck: Bool { return self == .transmittingAddressAck || self == .transmittingDataAck }
        var isTransmittingByte: Bool { return self == .transmittingAddressByte || self == .transmittingDataByte }
        var ackTarget: Byte.Nature? { self == .transmittingAddressAck ? .address : self == .transmittingDataAck ? .data : nil }
        var byteNature: Byte.Nature? { self == .transmittingAddressByte ? .address : self == .transmittingDataByte ? .data : nil }
        var phase: Phase? { (self == .transmittingAddressByte || self == .transmittingDataByte) ? .byte : (self == .transmittingAddressAck || self == .transmittingDataAck) ? .ack : nil  }
    }
    
    enum TransmissionResult {
        case success(writtenBytes: [Byte], readBytes: [Byte])
        case aborted
    }
    
    var currentTransmissionState: TransmissionState = .waitingStart
    var currentTransmissionStatus: TransmissionStatus = .waitingStart
    var lastTransmissionResult: TransmissionResult?
    let onTransmissionEnded: ((TransmissionResult)->())?
    
    var lastKnownLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) = (SCL: .high, SDA: .high)
    
    var bytesToBeRead: [Byte] = [0x01, 0x02]
    let nextBytesToBeRead: (() -> [Byte])?
    
    var lastTransmittedBit: Bit?
    var lastTransmittedAck: Ack?
    
    var lastTransmittedByte: Byte?
    var transmittedDataBytes: [Byte] = []
    
    var currentTransmittedByteReadBits: [Bit] = []
    var currentTransmittedByteIndex: Int = 0
    var currentTransmittedByteBitIndex: Int { currentTransmittedByteReadBits.count }
    
    var currentTransmissionMode: ReadWrite = .writeToSlave

    var nextAck: Ack?
    
    let address: Byte
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?


    init(
        address: Byte,
        acceptWrites: Bool,
        acceptReads: Bool,
        maxWrites: Int? = nil,
        nextBytesToBeRead: (() -> [Byte])? = nil,
        onTransmissionEnded: ((TransmissionResult)->())? = nil
    ) {
        self.address = address
        self.acceptWrites = acceptWrites
        self.acceptReads = acceptReads
        self.maxWrites = maxWrites
        self.nextBytesToBeRead = nextBytesToBeRead
        self.onTransmissionEnded = onTransmissionEnded
    }


    override func reset(x: CGFloat) {

        resetTransmissionState()
        lastKnownLineLevels = bus.currentLineLevels
        
        self.pullingSCL = false
        self.pullingSDA = false
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
                
                switch currentTransmissionState {
                    
                case .waitingStart,
                     .stopped:
                    break
                    
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
                        bitSetupPhaseStarted()
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
        
        currentTransmissionState = .waitingStart
        currentTransmissionStatus = .waitingStart
        lastTransmissionResult = nil
        nextAck = nil
    }
    
    
    func transmissionStarted() {
        
        currentTransmissionState = .started
        currentTransmissionStatus = .transmittingAddressByte
    }
    
    
    func bitSetupPhaseStarted() {
        
        currentTransmissionState = .bitClockLow
         
        switch currentTransmissionStatus {
            
        case .waitingStart,
             .transmittingAddressByte,
             .completed,
             .addressNacked:
            self.pullingSDA = false
            
        case .transmittingAddressAck,
             .transmittingDataAck:
            self.pullingSDA = nextAck == .ack
            
        case .transmittingDataByte:
            self.pullingSDA = currentTransmissionMode == .readFromSlave && nextDataBitToWrite == .zero
        }
    }
    
    
    func bitClockHighPhaseStarted() {
        
        currentTransmissionState = .bitClockHigh
    }
    
    
    func bitClockHighPhaseActive() {
        
        lastTransmittedBit = bus.lineSDA.currentLevel.bit
    }
    
    
    func bitClockHighPhaseEnded() {
        
        self.pullingSDA = false
        
        switch currentTransmissionStatus.phase! {

        case .byte:
            currentTransmittedByteReadBits.append(lastTransmittedBit!)
            if currentTransmittedByteReadBits.count == 8 {
                
                lastTransmittedByte = Byte(from: currentTransmittedByteReadBits)
                currentTransmittedByteReadBits = []
                receivedByte()
            }
            
        case .ack:
            lastTransmittedAck = Ack(from: lastTransmittedBit!)
            receivedAck()
        }
    }
    
    
    func receivedByte() {
        
        switch currentTransmissionStatus.byteNature! {

        case .address:
            
            let addressByte = lastTransmittedByte!
            let address = (addressByte >> 1)
            let rwBit = Bit(addressByte & 1)
            let rw: ReadWrite = rwBit == .zero ? .writeToSlave : .readFromSlave
            
            let addressMatch = address == self.address
            let acceptRW = (rw == .writeToSlave && acceptWrites || rw == .readFromSlave && acceptReads)
            
            if addressMatch && acceptRW {
                currentTransmissionMode = rw
                nextAck = .ack
            } else {
                nextAck = .nack
            }
            currentTransmissionStatus = .transmittingAddressAck
            
        case .data:
            
            transmittedDataBytes.append(lastTransmittedByte!)
            
            switch currentTransmissionMode {
            case .writeToSlave:
                nextAck = Ack(ackIf: maxWrites == nil || transmittedDataBytes.count < maxWrites!)
            case .readFromSlave:
                nextAck = nil
            }
            currentTransmissionStatus = .transmittingDataAck
        }
    }
    
    
    func receivedAck() {
        
        switch (lastTransmittedAck!, currentTransmissionStatus.ackTarget!) {
            
        case (.ack, .address):
            currentTransmittedByteIndex = 0
            currentTransmissionStatus = .transmittingDataByte
            
        case (.nack, .address):
            currentTransmissionStatus = .addressNacked
            
        case (.ack, .data):
            currentTransmittedByteIndex += 1
            currentTransmissionStatus = .transmittingDataByte
            
        case (.nack, .data):
            currentTransmissionStatus = .completed
        }
    }
    
    
    func transmissionStopped() {
        
        switch currentTransmissionStatus {
            
        case .waitingStart,
             .addressNacked:
            break
            
        case .transmittingAddressByte,
             .transmittingAddressAck,
             .transmittingDataByte,
             .transmittingDataAck:
            lastTransmissionResult = .aborted
            
        case .completed:
            let isWrite = currentTransmissionMode == .writeToSlave
            let isRead = currentTransmissionMode == .readFromSlave
            lastTransmissionResult = .success(
                writtenBytes: isWrite ? transmittedDataBytes : [],
                readBytes: isRead ? transmittedDataBytes : []
            )
        }
        
        let result = lastTransmissionResult
        resetTransmissionState()
        if let result = result {
            onTransmissionEnded?(result)
        }
    }
    
    
    var nextDataBitToWrite: Bit {
        
        if currentTransmittedByteIndex < bytesToBeRead.count {
            var nextBytes = nextBytesToBeRead?() ?? []
            if nextBytes.isEmpty {
                nextBytes.append(0xFF)
            }
            for byte in nextBytes {
                bytesToBeRead.append(byte)
            }
        }
        let byte = bytesToBeRead[currentTransmittedByteIndex]
        return byte.bit(atIndex: currentTransmittedByteBitIndex)
    }
}
