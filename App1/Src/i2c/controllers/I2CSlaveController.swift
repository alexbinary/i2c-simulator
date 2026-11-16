
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    let address: UInt8
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?

    private var transmissionFSM = I2CTransmissionFSM()
    private var transmissionActive = false

    private var readBytes: [UInt8] = []
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

        print("")
        print("-- SLAVE \(address) UPDATED STATE --")
        print("bus state: \(busFSM.currentState)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("readBytes: \(readBytes)")
        print("pullNextBit: \(pullNextBit)")
    }


    override func _initState() {

        resetTransmission()
    }


    override func _updateBusControl(x: CGFloat) {

        transmissionFSM.update(x: x, updatedBusFSM: busFSM,
            onClockedBit: {
                if transmissionActive {
                    print("-- SLAVE READ BIT --")
                    onClockedBit()
                }
            },
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

        updateControls(for: transmissionFSM)
    }


    private func updateControls(for transmissionFSM: I2CTransmissionFSM) {

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
        readBytes = []
        pullNextBit = false
    }


    private func onClockedBit() {

        pullNextBit = false

        switch transmissionFSM.currentMacroState {
        
        case .transmittingAddress:

            if transmissionFSM.currentByteComplete {

                let byte = transmissionFSM.lastReadByte!
                
                let address = (byte >> 1)
                let rwBit = Bit(byte & 1)
                let rw: ReadWrite = rwBit == .zero ? .write : .read
                
                let addressMatch = address == self.address
                let acceptRW = (rw == .write && acceptWrites || rw == .read && acceptReads)
                
                if addressMatch && acceptRW {
                    pullNextBit = true
                } else {
                    transmissionActive = false
                }
            }
            
        case .transmittingAddressAck:
            break
            
        case .transmittingByte:

            if transmissionFSM.currentByteComplete {

                readBytes.append(transmissionFSM.lastReadByte!)

                if maxWrites == nil || readBytes.count < maxWrites! {
                    pullNextBit = true
                }
            }
            
        case .transmittingByteAck:
            break
        }
    }
}
