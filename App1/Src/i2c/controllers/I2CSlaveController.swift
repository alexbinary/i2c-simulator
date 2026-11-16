
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    let address: UInt8
    let acceptWrites: Bool
    let acceptReads: Bool
    let maxWrites: Int?

    private var transmissionFSM = I2CTransmissionFSM()
    private var transmissionActive = false

    private var readingAddress = false
    private var readBits: [Bit] = []
    private var pullNextBit = false
    private var readBytes: [UInt8] = []


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
        print("readingAddress: \(readingAddress)")
        print("readBits: \(readBits)")
        print("pullNextBit: \(pullNextBit)")
        print("readBytes: \(readBytes)")
    }


    override func _initState() {

        resetTransmission()
    }


    override func _updateBusControl(x: CGFloat) {

        transmissionFSM.update(x: x, updatedBusFSM: busFSM,
            onClockedBit: { bit in
                if transmissionActive {
                    print("-- SLAVE READ BIT: \(bit) --")
                    onClockedBit(bit)
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
        readingAddress = true
        
        readBits = []
        pullNextBit = false
        readBytes = []
    }


    private func onClockedBit(_ bit: Bit) {

        readBits.append(bit)

        pullNextBit = false

        if readBits.count == 8 {

            let byte = byte(from: readBits)

            if readingAddress {

                let address = (byte >> 1)
                let rwBit = readBits[7]
                let rw: ReadWrite = rwBit == .zero ? .write : .read
                
                let addressMatch = address == self.address
                let acceptRW = (rw == .write && acceptWrites || rw == .read && acceptReads)
                
                if addressMatch && acceptRW {
                    pullNextBit = true
                } else {
                    transmissionActive = false
                }

            } else {

                readBytes.append(byte)

                if maxWrites == nil || readBytes.count < maxWrites! {
                    pullNextBit = true
                }
            }

        } else if readBits.count == 9 {

            readBits = []
            readingAddress = false
        }
    }


    private func byte(from bits:[Bit]) -> UInt8 {

        return bits
            .map { $0 == .zero ? 0 : 1 }
            .reduce(0, { byte, bit in (byte << 1) + bit })
    }
}
