
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    enum TransmissionInterractionState {
        case engaged
        case ignored
    }
    
    
    let address: UInt8
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?
    
    let nextBytesForMasterRead: (() -> [UInt8])?
    let onWriteSuccess: (([UInt8])->())?
    
    var bytes: [UInt8] = [0x01, 0x02]

    var passiveTransmissionMonitor = I2CTransmissionPassiveStateMachine()
    var currentTransmissionInterractionState: TransmissionInterractionState = .engaged
    var transmissionMode: ReadWrite = .write

    private var pullNextBit = false


    init(
        address: UInt8,
        acceptWrites: Bool,
        acceptReads: Bool,
        maxWrites: Int? = nil,
        nextBytesForMasterRead: (() -> [UInt8])? = nil,
        onWriteSuccess: (([UInt8])->())? = nil
    ) {
        self.address = address
        self.acceptWrites = acceptWrites
        self.acceptReads = acceptReads
        self.maxWrites = maxWrites
        self.nextBytesForMasterRead = nextBytesForMasterRead
        self.onWriteSuccess = onWriteSuccess
    }


    func printState() {

//        print("")
//        print("-- SLAVE \(address) UPDATED STATE --")
//        print("bus state: \(busFSM.currentState)")
//        print("transmission state: \(transmissionFSM.currentState)")
//        print("readBytes: \(readBytes)")
//        print("pullNextBit: \(pullNextBit)")
    }


    override func initState(x: CGFloat) {

        resetTransmissionState()
    }


    override func updateBusControl(x: CGFloat) {

//        passiveTransmissionMonitor.update(
//            afterLineChange: changedLine,
//            
//            onReadAddressByte: { addressByte in
//                
//                let address = (addressByte >> 1)
//                let rwBit = Bit(addressByte & 1)
//                let rw: ReadWrite = rwBit == .zero ? .write : .read
//                
//                let addressMatch = address == self.address
//                let acceptRW = (rw == .write && acceptWrites || rw == .read && acceptReads)
//                
//                if addressMatch && acceptRW {
//                    transmissionMode = rw
//                } else {
//                    currentTransmissionInterractionState = .ignored
//                }
//            },
//            onReadAddressAck: { _ in
//            },
//            onReadDataByte: { _ in
//            },
//            onReadDataAck: { _ in
//            },
//            onReadBit: { bit in
//                guard currentTransmissionInterractionState == .engaged else { return }
//                prepareNextBit()
//            },
//            onDone: { readBytes in
//                let writeSuccess = currentTransmissionInterractionState == .engaged && transmissionMode == .write
//                resetTransmissionState()
//                printState()
//                if writeSuccess {
//                    onWriteSuccess?(readBytes)
//                }
//            },
//            onAborted: {
//                resetTransmissionState()
//                printState()
//            }
//        )
//        printState()
        
        //            switch passiveTransmissionMonitor.currentTransmissionState {
        //            case .waitingIdle:
        //                break
        //
        //            case .waitingSDADrop:
        //                break
        //
        //            case .bitClockLow:
        //                self.pullingSDA = pullNextBit
        //
        //            case .bitClockHigh:
        //                break
        //            }
    }


    func resetTransmissionState() {

        passiveTransmissionMonitor.reset(lineLevels: bus.currentLineLevels)
        currentTransmissionInterractionState = .engaged
        
        prepareNextBit()
    }


    func prepareNextBit() {

        pullNextBit = false
        
        switch passiveTransmissionMonitor.currentTransmissionStep {
            
        case .transmittingAddressByte:
            break
            
        case .transmittingAddressAck:
            pullNextBit = true
            
        case .transmittingDataByte:
            if transmissionMode == .read {
                pullNextBit = nextDataBitToWrite == .zero
            }
            
        case .transmittingDataAck:
            if transmissionMode == .write {
                let ack = Ack(ackIf: maxWrites == nil || passiveTransmissionMonitor.currentByteIndex < maxWrites!)
                pullNextBit = ack.bit == .zero
            }
        }
    }
    
    
    var nextDataBitToWrite: Bit {
        
        if passiveTransmissionMonitor.currentByteIndex < bytes.count {
            
            var nextBytes = nextBytesForMasterRead?() ?? []
            if nextBytes.isEmpty {
                nextBytes.append(0xFF)
            }
            for byte in nextBytes {
                bytes.append(byte)
            }
        }
        
        let byte = bytes[passiveTransmissionMonitor.currentByteIndex]
        return byte.bit(atIndex: passiveTransmissionMonitor.currentByteBitIndex)
    }
}
