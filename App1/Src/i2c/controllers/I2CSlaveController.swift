
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    let address: UInt8
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?
    
    let nextBytesForMasterRead: (() -> [UInt8])?
    let onWriteSuccess: (([UInt8])->())?
    
    var bytes: [UInt8] = [0x01, 0x02]

    var transmissionFSM = I2CTransmissionPassiveStateMachine()
    var transmissionIsAddressedToSelf = true
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


    override func updateBusControl(after event: I2CBusEvent) {

        switch event {
        case .lineChange(let changedLine):
            
            transmissionFSM.update(
                afterLineChange: changedLine,
                onBitClocked: onBitClocked,
                onDone: { readBytes in
                    let writeSuccess = transmissionIsAddressedToSelf && transmissionMode == .write
                    resetTransmissionState()
                    printState()
                    if writeSuccess {
                        onWriteSuccess?(readBytes)
                    }
                },
                onAborted: {
                    resetTransmissionState()
                    printState()
                }
            )
            printState()
            
            switch transmissionFSM.currentMicroState {
            case .waitingStart:
                break
                
            case .started:
                
                switch transmissionFSM.bitFSM.currentState {
                case .setup:
                    
                    self.pullingSDA = pullNextBit
                    
                case .clocking:
                    break
                }
            }
            
        case .timeStep:
            break
        }
    }


    func resetTransmissionState() {

        transmissionFSM.reset(lineLevels: bus.currentLineLevels)
        transmissionIsAddressedToSelf = true
        prepareNextBit()
    }


    func onBitClocked(bit: Bit, transmissionMacroState: I2CTransmissionPassiveStateMachine.MacroState, byteIndex: Int) {

        if transmissionIsAddressedToSelf {
            prepareNextBit()
        }
    }


    func prepareNextBit() {

        pullNextBit = false
        
        switch transmissionFSM.currentMacroState {
            
        case .transmittingAddressByte:
            break
            
        case .transmittingAddressAck:
            
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
                transmissionIsAddressedToSelf = false
            }
            
            
        case .transmittingDataByte:
            
            if transmissionMode == .read {
                pullNextBit = nextDataBitToWrite == .zero
            }
            
        case .transmittingDataAck:
            
            if transmissionMode == .write {
                pullNextBit = maxWrites == nil || transmissionFSM.currentByteIndex < maxWrites!
            }
        }
    }
    
    
    var nextDataBitToWrite: Bit {
        
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
        return byte.bit(atIndex: transmissionFSM.currentByteBitIndex)
    }
}
