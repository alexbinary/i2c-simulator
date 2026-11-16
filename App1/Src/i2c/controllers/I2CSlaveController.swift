
import SwiftUI



class I2CSlaveController: I2CController {
    
    
    private var transmissionFSM = I2CPassiveTransmissionFSM()


    private var readBit = 0
    private var writingBit = false
    private var currentBitToWrite: Bit = .zero


    private func printState() {

        print("")
        print("-- SLAVE UPDATED STATE --")
        print("bus state: \(busFSM.currentState)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("transmission result: \(transmissionFSM.result)")
        print("readBit: \(readBit)")
        print("writingBit: \(writingBit)")
        print("currentBitToWrite: \(currentBitToWrite)")
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

                if writingBit {
                    if currentBitToWrite == .zero && busFSM.lineLevels.SDA == .high {
                        self.pullingSDA = true
                        return
                    }
                    if currentBitToWrite == .one && busFSM.lineLevels.SDA == .low {
                        self.pullingSDA = false
                        return
                    }
                } else {
                    self.pullingSDA = false
                }

            case .clockHigh:
                break
            }

            return
        }
    }


    private func readBit(_ bit: Bit) {

        readBit += 1
        if readBit == 8 {
            writingBit = true
            currentBitToWrite = .zero
        }
    }
}
