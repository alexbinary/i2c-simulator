
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil

    private var sendingStop = false
    private var writingBit = false
    
    private var currentByteIndex = -1
    private var currentByteToWrite: UInt8 = 0x00
    private var currentBitIndex = -1
    private var nextBitToWrite: Bit = .zero

    private var readBytes: [UInt8] = []
    
    private var transmissionFSM = I2CTransmissionFSM()

    private let xWaitBeforeStart: CGFloat = 10
    private let xWaitAfterStart: CGFloat = 10

    private let xWaitBeforeBitClockHigh: CGFloat = 10
    private let xWaitBitClockHigh: CGFloat = 10
    private let xWaitAfterBitClockHigh: CGFloat = 10

    private let xWaitBeforeStop: CGFloat = 10
    private let xWaitAfterStop: CGFloat = 100
    
    private var xTimerCurrent: CGFloat!
    private var xTimerTargetStart: CGFloat?
    private var xTimerTargetClockBitLowStart: CGFloat?
    private var xTimerTargetClockBitHighStart: CGFloat?
    private var xTimerTargetClockBitHighEnd: CGFloat?
    private var xTimerTargetStopStart: CGFloat?
    private var xTimerTargetStopEnd: CGFloat?
    
    
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
        print("readBytes: \(readBytes)")
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
                onClockedBit: {
                    onClockedBit()
                },
                onStop: {
                    xTimerTargetStopEnd = xTimerCurrent + xWaitAfterStop
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


    private func updateControls(for transmissionFSM: I2CTransmissionFSM) {

        switch transmissionFSM.currentState {
        case .waitingStart:

            switch transmissionFSM.startFSM.currentState {
            case .waitingIdle:

                xTimerTargetClockBitLowStart = nil
                xTimerTargetClockBitHighStart = nil
                xTimerTargetStopStart = nil

                self.pullingSDA = false
                self.pullingSCL = false

            case .waitingSDApull:

                xTimerTargetStart = xTimerTargetStart ?? (xTimerCurrent + xWaitBeforeStart)
                if xTimerCurrent < xTimerTargetStart! {
                    return
                }
                if let xTimerTargetStopEnd = xTimerTargetStopEnd, xTimerCurrent < xTimerTargetStopEnd {
                    return
                }
                self.pullingSDA = true
            }

        case .started:

            let delay = ((transmissionFSM.currentMacroState == .transmittingAddress && transmissionFSM.currentByteBitIndex == 0) || sendingStop) ? xWaitAfterStart : xWaitAfterBitClockHigh
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

        readBytes = []
        sendingStop = false

        writingBit = true
        nextBitToWrite = nextAddressBitToWrite()

        xTimerTargetStart = nil
    }


    private func onClockedBit() {

        switch transmissionFSM.currentMacroState {
        
        case .transmittingAddress:

            if !transmissionFSM.currentByteComplete {

                writingBit = true
                nextBitToWrite = nextAddressBitToWrite()

            } else {

                writingBit = false
            }

        case .transmittingAddressAck:
            
            let ackBit = transmissionFSM.lastReadBit!
            let ack = ackBit == .zero
            if !ack {

                sendingStop = true

            } else {

                switch activeTransmission!.mode {
                case .write:
                    writingBit = true
                    nextBitToWrite = nextDataBitToWrite()
                case .read:
                    writingBit = false
                }
            }
            
        case .transmittingByte:

            switch activeTransmission!.mode {
            case .write:

                if !transmissionFSM.currentByteComplete {

                    writingBit = true
                    nextBitToWrite = nextDataBitToWrite()

                } else {

                    writingBit = false
                }

            case .read:

                if transmissionFSM.currentByteComplete {

                    readBytes.append(transmissionFSM.lastReadByte!)

                    if readBytes.count < activeTransmission!.numBytes {

                        writingBit = true
                        nextBitToWrite = .zero
                    }
                }
            }
            
        case .transmittingByteAck:
            
            switch activeTransmission!.mode {
            case .write:

                let ackBit = transmissionFSM.lastReadBit!
                let ack = ackBit == .zero
                if !ack {

                    sendingStop = true

                } else {

                    writingBit = true
                    nextBitToWrite = nextDataBitToWrite()
                }

            case .read:

                if readBytes.count == activeTransmission!.numBytes {

                    sendingStop = true
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
