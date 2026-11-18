
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    private let address: UInt8
    private let acceptWrites: Bool
    private let acceptReads: Bool
    private let maxWrites: Int?
    
    private let nextBytesForMasterRead: (() -> [UInt8])?
    private let onWriteSuccess: (([UInt8])->())?
    
    private var bytes: [UInt8] = [0x01, 0x02]

    private var transmissionFSM = I2CTransmissionFSM()
    private var transmissionActive = false
    private var transmissionMode: ReadWrite = .write

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


    private func printState() {

//        print("")
//        print("-- SLAVE \(address) UPDATED STATE --")
//        print("bus state: \(busFSM.currentState)")
//        print("transmission state: \(transmissionFSM.currentState)")
//        print("readBytes: \(readBytes)")
//        print("pullNextBit: \(pullNextBit)")
    }


    override func initState(x: CGFloat, levelSCL: LineLevel, levelSDA: LineLevel) {

        transmissionFSM.reset(levelSCL: levelSCL, levelSDA: levelSDA)
        resetTransmission()
    }


    override func updateBusControl(after event: I2CBusEvent) {

        transmissionFSM.update(after: event,
            onBitClocked: onBitClocked,
            onDone: { readBytes in
                print("-- SLAVE TRANSMISSION DONE --")
                let writeSuccess = transmissionActive && transmissionMode == .write
                resetTransmission()
                printState()
                if writeSuccess {
                    onWriteSuccess?(readBytes)
                }
            },
            onAborted: {
                print("-- SLAVE TRANSMISSION ABORTED --")
                resetTransmission()
                printState()
            }
        )
        printState()
        
        switch transmissionFSM.currentTransmissionState {
        case .waitingStart:
            break

        case .started:

            switch transmissionFSM.bitFSM.currentState {
            case .setup:

                self.pullingSDA = pullNextBit

            case .clockHigh:
                break
            }
        }
    }


    private func resetTransmission() {

        transmissionActive = true
        prepareNextBit()
    }


    private func onBitClocked(bit: Bit, transmittingAddress: Bool, transmittingAck: Bool, byteIndex: Int, byteBitIndex: Int, byteComplete: Bool, byte: UInt8?) {

        if !transmissionActive {
            return
        }
        
        prepareNextBit()
    }


    private func prepareNextBit() {

        pullNextBit = false

        if transmissionFSM.transmittingAddress, transmissionFSM.transmittingAck {
        
            let addressByte = transmissionFSM.lastReadByte!
            
            let address = (addressByte >> 1)
            let rwBit = Bit(addressByte & 1)
            let rw: ReadWrite = rwBit == .zero ? .write : .read
            
            let addressMatch = address == self.address
            let acceptRW = (rw == .write && acceptWrites || rw == .read && acceptReads)
            
            if addressMatch && acceptRW {
                pullNextBit = true
                transmissionMode = rw
            } else {
                transmissionActive = false
            }
        }
        
        if !transmissionFSM.transmittingAddress, transmissionMode == .write, transmissionFSM.transmittingAck {
                    
            pullNextBit = maxWrites == nil || transmissionFSM.currentByteIndex < maxWrites!
        }
    
        if !transmissionFSM.transmittingAddress, transmissionMode == .read, !transmissionFSM.transmittingAck {
                    
            pullNextBit = nextDataBitToWrite == .zero
        }
    }
    
    
    private var nextDataBitToWrite: Bit {
        
        if transmissionFSM.currentByteIndex < bytes.count {
            
            var nextBytes = nextBytesForMasterRead?() ?? []
            if nextBytes.isEmpty {
                nextBytes.append(0xFF)
            }
            for byte in nextBytes {
                bytes.append(byte)
            }
        }
        
        let byte = bytes[transmissionFSM.currentByteIndex]
        return bit(fromByte: byte, atIndex: transmissionFSM.currentByteBitIndex)
    }
    
    
    private func bit(fromByte byte: UInt8, atIndex bitIndex: Int) -> Bit {
        
        return Bit((byte >> (7-bitIndex)) & 1)
    }
}
