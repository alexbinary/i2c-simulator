
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}


enum TransmissionByteType: Equatable {

    case addressRW
    case data(index: Int)
}


enum TransmissionBitType: Equatable {

    case bit(index: Int)
    case ack
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil

    private var currentTransmissionByteType: TransmissionByteType? = nil
    private var currentTransmissionByte: UInt8? {
        switch currentTransmissionByteType {
        case .addressRW: return activeTransmission?.addressRW
        case .data(let index): return activeTransmission?.bytes[index]
        case .none: return nil
        }
    }
    private var currentTransmissionBitType: TransmissionBitType? = nil
    private var currentTransmissionWriteBit: Bit? {
        if currentTransmissionByte == nil { return nil }
        switch currentTransmissionBitType {
        case .bit(let index): return Bit((Int(currentTransmissionByte!) >> (7-index)) & 1)
        case .ack: return nil
        case .none: return nil
        }
    }

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
        print("currentTransmissionByteType: \(currentTransmissionByteType)")
        print("currentTransmissionByte: \(currentTransmissionByte)")
        print("currentTransmissionBitType: \(currentTransmissionBitType)")
        print("currentTransmissionWriteBit: \(currentTransmissionWriteBit)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("transmission result: \(transmissionFSM.result)")
        print("start state: \(transmissionFSM.startFSM.currentState)")
        print("stop state: \(transmissionFSM.stopFSM.currentState)")
        print("bit state: \(transmissionFSM.bitFSM.currentState)")
    }
    
    
    override func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {

        timerUpdate(x: x)
        printState()

        while true {

            if activeTransmission == nil {

                if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= x {

                    scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                    activeTransmission = entry.transmission
                    currentTransmissionByteType = .addressRW
                    currentTransmissionBitType = .bit(index: 0)
                    printState()

                } else {

                    break
                }
            }

            if activeTransmission != nil {

                transmissionFSM.update(x: x, updatedBusFSM: busFSM,
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

                return currentAction(for: transmissionFSM)
            }
        }

        return nil
    }


    private func timerUpdate(x: CGFloat) {

        xTimerCurrent = x
    }


    private func currentAction(for transmissionFSM: I2CPassiveTransmissionFSM) -> I2CControllerLineAction? {

        switch transmissionFSM.currentState {
        case .waitingStart:

            switch transmissionFSM.startFSM.currentState {
            case .waitingIdle:

                xTimerTargetStart = nil
                xTimerTargetClockBitLowStart = nil
                xTimerTargetClockBitHighStart = nil

                if busFSM.lineLevels.SDA == .low {
                    return .releaseSDA
                }
                if busFSM.lineLevels.SCL == .low {
                    return .releaseSCL
                }

                fatalError("state not expected to be reachable")

            case .waitingSDApull:

                xTimerTargetStart = xTimerTargetStart ?? (xTimerCurrent + xWaitBeforeStart)
                if xTimerCurrent < xTimerTargetStart! {
                    return nil
                } else {
                    return .pullSDA
                }
            }

        case .started:

            if let currentTransmissionByteType = currentTransmissionByteType {

                switch transmissionFSM.bitFSM.currentState {
                case .setup:

                    xTimerTargetClockBitHighEnd = nil

                    let delay = currentTransmissionByteType == .addressRW && currentTransmissionBitType == .bit(index: 0) ? xWaitAfterStart : xWaitAfterBitClockHigh
                    xTimerTargetClockBitLowStart = xTimerTargetClockBitLowStart ?? (xTimerCurrent + delay)
                    if xTimerCurrent < xTimerTargetClockBitLowStart! {
                        return nil
                    }

                    if busFSM.lineLevels.SCL == .high {
                        return .pullSCL
                    }

                    switch currentTransmissionBitType {
                    case .bit(let index):
                        if currentTransmissionWriteBit == .zero && busFSM.lineLevels.SDA == .high {
                            return .pullSDA
                        }
                        if currentTransmissionWriteBit == .one && busFSM.lineLevels.SDA == .low {
                            return .releaseSDA
                        }
                    case .ack:
                        break
                    case .none:
                        fatalError()
                    }

                    xTimerTargetClockBitHighStart = xTimerTargetClockBitHighStart ?? (xTimerCurrent + xWaitBeforeBitClockHigh)
                    if xTimerCurrent < xTimerTargetClockBitHighStart! {
                        return nil
                    } else {
                        return .releaseSCL
                    }

                case .clockHigh:

                    xTimerTargetClockBitLowStart = nil
                    xTimerTargetClockBitHighStart = nil
                    
                    xTimerTargetClockBitHighEnd = xTimerTargetClockBitHighEnd ?? (xTimerCurrent + xWaitBitClockHigh)
                    if xTimerCurrent < xTimerTargetClockBitHighEnd! {
                        return nil
                    } else {
                        // read bit
                        // move to next bit
                        return .pullSCL
                    }
                }

            } else {

                // send stop
                return nil
            }
        }
    }
}
