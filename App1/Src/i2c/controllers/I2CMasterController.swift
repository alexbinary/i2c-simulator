
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private let onReadSuccess: (([UInt8])->())?
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil
    private var addressAcked: Bool = false

    private var sendingStop = false
    private var holdingBus = false
    private var writingBit = false
    private var nextBitToWrite: Bit = .zero
    
    private var transmissionFSM = I2CTransmissionFSM()

    private let xWaitBeforeStartSCLRelease: CGFloat = 10
    private let xWaitBeforeStartSDAPull: CGFloat = 10
    private let xWaitAfterStart: CGFloat = 10

    private let xWaitBeforeBitClockHigh: CGFloat = 10
    private let xWaitDuringBitClockHigh: CGFloat = 10
    private let xWaitAfterBitClockHigh: CGFloat = 10

    private let xWaitBeforeStop: CGFloat = 10
    private let xWaitAfterStop: CGFloat = 100
    
    private var currentX: CGFloat = 0
    private var nextTransmissionStartReleasesSCLAfterX: CGFloat = 0
    private var nextTransmissionStartPullsSDAAfterX: CGFloat = 0
    private var nextBitSetupStartsAfterX: CGFloat = 0
    private var nextBitClockHighStartsAfterX: CGFloat = 0
    private var nextBitClockHighEndsAfterX: CGFloat = 0
    private var transmissionStopStartsAfterX: CGFloat = 0
    private var transmissionStopEndsAtX: CGFloat?
    
    
    init(
        onReadSuccess: (([UInt8])->())?
    ) {
        self.onReadSuccess = onReadSuccess
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }


    private func printState() {

//        print("")
//        print("-- MASTER UPDATED STATE --")
//        print("timer: \(xTimerCurrent)")
//        print("bus state: \(busFSM.currentState)")
//        print("activeTransmission: \(activeTransmission)")
//        print("transmission state: \(transmissionFSM.currentState)")
//        print("transmission result: \(transmissionFSM.result)")
//        print("start state: \(transmissionFSM.startFSM.currentState)")
//        print("stop state: \(transmissionFSM.stopFSM.currentState)")
//        print("bit state: \(transmissionFSM.bitFSM.currentState)")
//        print("sendingStop: \(sendingStop)")
//        print("writingBit: \(writingBit)")
//        print("nextBitToWrite: \(nextBitToWrite)")
    }
    
    
    override func _updateBusControl(x: CGFloat) {

        currentX = x
        printState()

        if activeTransmission == nil {

            if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= x {

                scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                activeTransmission = entry.transmission

                initTransmissionState()

                printState()
            }
        }

        if activeTransmission != nil {

            transmissionFSM.update(x: x, updatedBusFSM: busFSM,
                onBitClocked: onBitClocked,
                onDone: onDone,
                onAborted: {
                    self.activeTransmission = nil
                    printState()
                }
            )
            printState()
        }

        if activeTransmission != nil {

            updateControls(for: transmissionFSM)
        }
    }
    
    
    private func onDone(readBytes: [UInt8]) {
        
        let readSuccess = self.activeTransmission!.mode == .read && addressAcked
        self.activeTransmission = nil
        transmissionFSM.reset()
        printState()
        if readSuccess {
            onReadSuccess?(readBytes)
        }
    }


    private func updateControls(for transmissionFSM: I2CTransmissionFSM) {

        switch transmissionFSM.currentState {
        case .waitingStart:

            switch transmissionFSM.startFSM.currentState {
            case .waitingIdle:

                if busFSM.lineLevels.SDA == .low {
                    self.pullingSDA = false
                    return
                }
                
                if currentX < nextTransmissionStartReleasesSCLAfterX {
                    return
                }
                
                if busFSM.lineLevels.SCL == .low {
                    self.pullingSCL = false
                    return
                }
                
                nextTransmissionStartPullsSDAAfterX = currentX + xWaitBeforeStartSDAPull

            case .waitingSDApull:

                if currentX < nextTransmissionStartPullsSDAAfterX {
                    return
                }
                
                self.pullingSDA = true
                nextBitSetupStartsAfterX = currentX + xWaitAfterStart
            }

        case .started:

            switch transmissionFSM.bitFSM.currentState {
            case .setup:
                
                if currentX < nextBitSetupStartsAfterX {
                    return
                }

                if busFSM.lineLevels.SCL == .high {
                    self.pullingSCL = true
                    nextBitClockHighStartsAfterX = currentX + xWaitBeforeBitClockHigh
                    return
                }

                if sendingStop {
                    if busFSM.lineLevels.SDA == .high {
                        self.pullingSDA = true
                        return
                    }
                } else if writingBit {
                    if nextBitToWrite == .zero && busFSM.lineLevels.SDA == .high {
                        self.pullingSDA = true
                        return
                    }
                    if nextBitToWrite == .one && busFSM.lineLevels.SDA == .low {
                        self.pullingSDA = false
                        return
                    }
                } else {
                    self.pullingSDA = false
                }

                if currentX < nextBitClockHighStartsAfterX {
                    return
                }
                
                if holdingBus {
                    onDone(readBytes: transmissionFSM.readBytes)
                } else {
                    self.pullingSCL = false
                    
                    nextBitClockHighEndsAfterX = currentX + xWaitDuringBitClockHigh
                    transmissionStopStartsAfterX = currentX + xWaitBeforeStop
                }

            case .clockHigh:
                
                if sendingStop {

                    if currentX < transmissionStopStartsAfterX {
                        return
                    }
                    
                    self.pullingSDA = false
                    
                    transmissionStopEndsAtX = currentX + xWaitAfterStop
                    nextTransmissionStartReleasesSCLAfterX = transmissionStopEndsAtX! + xWaitBeforeStartSCLRelease

                } else {

                    if currentX < nextBitClockHighEndsAfterX {
                        return
                    }
                    
                    self.pullingSCL = true
                    
                    nextBitSetupStartsAfterX = currentX + xWaitAfterBitClockHigh
                    nextBitClockHighStartsAfterX = nextBitSetupStartsAfterX + xWaitBeforeBitClockHigh
                }
            }

            return
        }
    }


    private func initTransmissionState() {

        sendingStop = false
        holdingBus = false
        addressAcked = false
        prepareNextBit()
        
        nextTransmissionStartReleasesSCLAfterX = max(nextTransmissionStartReleasesSCLAfterX, currentX + xWaitBeforeStartSCLRelease)
    }


    private func onBitClocked(bit: Bit, transmittingAddress: Bool, transmittingAck: Bool, byteIndex: Int, byteBitIndex: Int, byteComplete: Bool, byte: UInt8?) {

        sendingStop = false
        holdingBus = false
        
        if transmittingAck {
            
            let ackBit = bit
            let ack = ackBit == .zero
            
            if ack && transmittingAddress {
                addressAcked = true
            }

            if !ack || byteIndex == (activeTransmission!.bytes.count-1) {
                sendingStop = true
                holdingBus = true
            }
        }

        if !sendingStop {
            prepareNextBit()
        }
    }


    private func prepareNextBit() {

        if transmissionFSM.transmittingAddress {

            if !transmissionFSM.transmittingAck {

                writingBit = true
                nextBitToWrite = nextAddressBitToWrite()

            } else {

                writingBit = false
            }

        } else {

            if !transmissionFSM.transmittingAck {

                switch activeTransmission!.mode {
                case .write:
                    writingBit = true
                    nextBitToWrite = nextDataBitToWrite()
                case .read:
                    writingBit = false
                }

            } else {

                switch activeTransmission!.mode {
                case .write:
                    writingBit = false
                case .read:
                    writingBit = true
                    let ack = transmissionFSM.currentByteIndex < activeTransmission!.numBytes-1
                    nextBitToWrite = ack ? .zero : .one
                }
            }
        }
    }


    private func nextAddressBitToWrite() -> Bit {

        let byte = activeTransmission!.addressRW
        return bit(fromByte: byte, atIndex: transmissionFSM.currentByteBitIndex)
    }


    private func nextDataBitToWrite() -> Bit {

        let byte = activeTransmission!.bytes[transmissionFSM.currentByteIndex]
        return bit(fromByte: byte, atIndex: transmissionFSM.currentByteBitIndex)
    }


    private func bit(fromByte byte: UInt8, atIndex bitIndex: Int) -> Bit {

        return Bit((byte >> (7-bitIndex)) & 1)
    }
}
