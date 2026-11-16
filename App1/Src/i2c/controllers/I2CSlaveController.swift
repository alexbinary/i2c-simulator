
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    private var transmissionFSM = I2CPassiveTransmissionFSM()


    private var readBits = 0
    private var writingBit = false


    private func printState() {

        print("")
        print("-- SLAVE UPDATED STATE --")
        print("bus state: \(busFSM.currentState)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("transmission result: \(transmissionFSM.result)")
        print("readBits: \(readBits)")
        print("writingBit: \(writingBit)")
    }


    override func _updateBusControl(x: CGFloat) {

        transmissionFSM.update(x: x, updatedBusFSM: busFSM,
            onReadBit: { bit in
                print("-- SLAVE READ BIT: \(bit) --")
                readBit(bit)
            },
            onStop: {
                print("-- SLAVE TRANSMISSION STOP --")
                printState()
            },
            onDone: {
                print("-- SLAVE TRANSMISSION DONE --")
                printState()
            },
            onAborted: {
                print("-- SLAVE TRANSMISSION ABORTED --")
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

                self.pullingSDA = writingBit

            case .clockHigh:
                break
            }
        }
    }


    private func readBit(_ bit: Bit) {

        readBits += 1
        if readBits == 8 {
            writingBit = true
        }
    }
}
