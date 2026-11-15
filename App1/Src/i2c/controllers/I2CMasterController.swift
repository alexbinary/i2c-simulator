
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil

    private var sendingStop = false
    private var sendingAddress = false
    
    private var writingBit = false
    private var readingAck = false
    
    private var currentByteToWrite: UInt8 = 0x00
    private var currentBitIndex = -1
    private var currentBitToWrite: Bit = .zero
    
    private var transmissionFSM = I2CPassiveTransmissionFSM()

    private var xTimerCurrent: CGFloat!
    private var xTimerTargetStart: CGFloat?
    private var xTimerTargetClockBitLowStart: CGFloat?
    private var xTimerTargetClockBitHighStart: CGFloat?
    private var xTimerTargetClockBitHighEnd: CGFloat?
    private var xTimerTargetStopStart: CGFloat?
    private var xTimerTargetStopEnd: CGFloat?
    
    private let xWaitBeforeStart: CGFloat = 10
    private let xWaitAfterStart: CGFloat = 10

    private let xWaitBeforeBitClockHigh: CGFloat = 10
    private let xWaitBitClockHigh: CGFloat = 10
    private let xWaitAfterBitClockHigh: CGFloat = 10

    private let xWaitBeforeStop: CGFloat = 10
    private let xWaitAfterStop: CGFloat = 10
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }


    private func printState() {

        print("")
        print("-- MASTER UPDATED STATE --")
        print("timer: \(xTimerCurrent)")
        print("bus state: \(busFSM.currentState)")
        print("activeTransmission: \(activeTransmission)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("transmission result: \(transmissionFSM.result)")
        print("start state: \(transmissionFSM.startFSM.currentState)")
        print("stop state: \(transmissionFSM.stopFSM.currentState)")
        print("bit state: \(transmissionFSM.bitFSM.currentState)")
    }
    
    
    override func _updateBusControl(x: CGFloat) {

        timerUpdate(x: x)
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
                onReadBit: { bit in
                    readBit(bit)
                },
                onStop: {
                    xTimerTargetStopEnd = xTimerTargetStopEnd ?? (xTimerCurrent + xWaitAfterStop)
                },
                onDone: {
                    self.activeTransmission = nil
                    printState()
                },
                onAborted: {
                    self.activeTransmission = nil
                    printState()
                }
            )
            printState()
        }

        if let activeTransmission = activeTransmission {

            updateControls(for: transmissionFSM)
        }
    }


    private func timerUpdate(x: CGFloat) {

        xTimerCurrent = x
    }


    private func updateControls(for transmissionFSM: I2CPassiveTransmissionFSM) {

        switch transmissionFSM.currentState {
        case .waitingStart:

            switch transmissionFSM.startFSM.currentState {
            case .waitingIdle:

                xTimerTargetStart = nil
                xTimerTargetClockBitLowStart = nil
                xTimerTargetClockBitHighStart = nil
                xTimerTargetStopStart = nil

                if let xTimerTargetStopEnd = xTimerTargetStopEnd, xTimerCurrent < xTimerTargetStopEnd {
                    return
                }

                self.pullingSDA = false
                self.pullingSCL = false

            case .waitingSDApull:

                xTimerTargetStart = xTimerTargetStart ?? (xTimerCurrent + xWaitBeforeStart)
                if xTimerCurrent < xTimerTargetStart! {
                    return
                }
                self.pullingSDA = true
            }

        case .started:

            let delay = ((sendingAddress && currentBitIndex == 0) || sendingStop) ? xWaitAfterStart : xWaitAfterBitClockHigh
            xTimerTargetClockBitLowStart = xTimerTargetClockBitLowStart ?? (xTimerCurrent + delay)
            if xTimerCurrent < xTimerTargetClockBitLowStart! {
                return
            }

            switch transmissionFSM.bitFSM.currentState {
            case .setup:

                xTimerTargetClockBitHighEnd = nil

                if busFSM.lineLevels.SCL == .high {
                    self.pullingSCL = true
                    return
                }

                if sendingStop {
                    if busFSM.lineLevels.SDA == .high {
                        self.pullingSDA = true
                        return
                    }
                } else if writingBit {
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

                xTimerTargetClockBitHighStart = xTimerTargetClockBitHighStart ?? (xTimerCurrent + xWaitBeforeBitClockHigh)
                if xTimerCurrent < xTimerTargetClockBitHighStart! {
                    return
                }
                self.pullingSCL = false

            case .clockHigh:

                xTimerTargetClockBitLowStart = nil
                xTimerTargetClockBitHighStart = nil
                
                if sendingStop {

                    xTimerTargetStopStart = xTimerTargetStopStart ?? (xTimerCurrent + xWaitBeforeStop)
                    if xTimerCurrent < xTimerTargetStopStart! {
                        xTimerTargetStopEnd = nil
                        return
                    }
                    self.pullingSDA = false

                } else {

                    xTimerTargetClockBitHighEnd = xTimerTargetClockBitHighEnd ?? (xTimerCurrent + xWaitBitClockHigh)
                    if xTimerCurrent < xTimerTargetClockBitHighEnd! {
                        return
                    }
                    self.pullingSCL = true
                }
            }

            return
        }
    }


    private func initTransmissionState() {

        sendingAddress = true
        sendingStop = false
        
        writingBit = true
        readingAck = false
        
        currentByteToWrite = activeTransmission!.addressRW
        currentBitIndex = 0
        currentBitToWrite = Bit((Int(currentByteToWrite) >> (7-currentBitIndex)) & 1)
    }


    private func readBit(_ bit: Bit) {

        if readingAck {
            let ack = bit == .zero
            let nack = !ack
            if nack {
                sendingStop = true
            } else if ack {
                sendingStop = true
            }
        } else {
            if currentBitIndex < 7 {
                currentBitIndex += 1
                currentBitToWrite = Bit((Int(currentByteToWrite) >> (7-currentBitIndex)) & 1)
            } else {
                writingBit = false
                readingAck = true
            }
        }
    }
}
