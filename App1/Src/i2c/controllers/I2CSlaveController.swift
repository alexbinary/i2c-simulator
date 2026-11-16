
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    let address: UInt8

    private var transmissionFSM = I2CPassiveTransmissionFSM()

    private var readBits: [Bit] = []
    private var pullNextBit = false


    init(
        address: UInt8
    ) {
        self.address = address
    }


    private func printState() {

        print("")
        print("-- SLAVE \(address) UPDATED STATE --")
        print("bus state: \(busFSM.currentState)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("transmission result: \(transmissionFSM.result)")
        print("readBits: \(readBits)")
        print("pullNextBit: \(pullNextBit)")
    }


    override func _updateBusControl(x: CGFloat) {

        transmissionFSM.update(x: x, updatedBusFSM: busFSM,
            onReadBit: { bit in
                print("-- SLAVE READ BIT: \(bit) --")
                readBit(bit)
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


    private func updateControls(for transmissionFSM: I2CPassiveTransmissionFSM) {

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

        readBits = []
        pullNextBit = false
    }


    private func readBit(_ bit: Bit) {

        readBits.append(bit)
        if readBits.count == 8 {

            let byte = byte(from: readBits)
            if (byte >> 1) == address {
                pullNextBit = true
            }
        }
    }


    private func byte(from bits:[Bit]) -> UInt8 {

        return bits
            .map { $0 == .zero ? 0 : 1 }
            .reduce(0, { byte, bit in (byte << 1) + bit })
    }
}
