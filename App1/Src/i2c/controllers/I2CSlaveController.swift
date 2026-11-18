
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    let address: UInt8
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?

    private var transmissionFSM = I2CTransmissionFSM()
    private var transmissionActive = false
    private var transmissionMode: ReadWrite = .write

    private var pullNextBit = false


    init(
        address: UInt8,
        acceptWrites: Bool,
        acceptReads: Bool,
        maxWrites: Int? = nil
    ) {
        self.address = address
        self.acceptWrites = acceptWrites
        self.acceptReads = acceptReads
        self.maxWrites = maxWrites
    }


    private func printState() {

//        print("")
//        print("-- SLAVE \(address) UPDATED STATE --")
//        print("bus state: \(busFSM.currentState)")
//        print("transmission state: \(transmissionFSM.currentState)")
//        print("readBytes: \(readBytes)")
//        print("pullNextBit: \(pullNextBit)")
    }


    override func _initState() {

        resetTransmission()
    }


    override func _updateBusControl(x: CGFloat) {

        transmissionFSM.update(x: x, updatedBusFSM: busFSM,
            onBitClocked: onBitClocked,
            onStop: {
                print("-- SLAVE TRANSMISSION STOP --")
                resetTransmission()
                printState()
            },
            onDone: {
                print("-- SLAVE TRANSMISSION DONE --")
                resetTransmission()
                printState()
            },
            onAborted: {
                print("-- SLAVE TRANSMISSION ABORTED --")
                resetTransmission()
                printState()
            }
        )
        printState()
        
        switch transmissionFSM.currentState {
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

        if transmissionFSM.transmittingAddress {
            
            if transmissionFSM.transmittingAck {

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

        } else {

            if transmissionFSM.transmittingAck {
                
                if transmissionMode == .write {
                    
                    if maxWrites == nil || transmissionFSM.currentByteIndex < maxWrites! {
                        pullNextBit = true
                    }
                }

            } else {

                // TODO send data
            }
        }
    }
}
