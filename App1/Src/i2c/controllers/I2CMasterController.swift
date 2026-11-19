
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    enum TransmissionDriveState {
        case start_waitingBeforeReleasingSDA
        case start_releasingSDA
        case start_waitingBeforeReleasingSCL
        case start_releasingSCL
        case start_waitingBeforeSDADrop
        case start_droppingSDA
        case start_waitingAfterSDADrop
        case bitSetup_waitingBeforePullingSCL
        case bitSetup_pullingSCL
        case bitSetup_waitingBeforeAssertingSDA
        case bitSetup_assertingSDA
        case bitSetup_waitingBeforeBitClock
        case bitSetup_releasingSCL
        case bitClock_waitingDuringBitClock
        case bitClock_pullingSCL
        case bitClock_waitingAfterBitClock
        case stop_waitingBeforeReleasingSCL
        case stop_releasingSCL
        case stop_waitingBeforeReleasingSDA
        case stop_releasingSDA
        case stop_waitingAfterSDARelease
    }
    
    
    let onReadSuccess: (([UInt8])->())?
    
    var scheduledTransmissions: [ScheduledTransmission] = []
    var activeTransmission: I2CTransmission? = nil
    var addressAcked: Bool = false

    var sendingStop = false
    var holdingBus = false
    var writingBit = false
    var nextBitToWrite: Bit?
    
    var passiveTransmissionMonitor = I2CTransmissionPassiveStateMachine()
    var currentTransmissionDriveState: TransmissionDriveState = .start_releasingSDA

    let xWaitBeforeStartSDARelease: CGFloat = 10
    let xWaitBeforeStartSCLRelease: CGFloat = 10
    let xWaitBeforeStartSDAPull: CGFloat = 10
    let xWaitAfterStart: CGFloat = 10
    let xWaitBeforeBitClockHigh: CGFloat = 10
    let xWaitDuringBitClockHigh: CGFloat = 10
    let xWaitAfterBitClockHigh: CGFloat = 10
    let xWaitBeforeStop: CGFloat = 10
    let xWaitAfterStop: CGFloat = 100
    
    var currentX: CGFloat = 0
    var nextTransmissionStartSDAReleaseMinX: CGFloat = 0
    var nextTransmissionStartSCLReleaseMinX: CGFloat = 0
    var nextTransmissionStartSDAPullMinX: CGFloat = 0
    var nextTransmissionStartEndMinX: CGFloat = 0
    var nextBitSetupSCLPullMinX: CGFloat = 0
    var nextBitSetupSDAAssertMinX: CGFloat = 0
    var nextBitClockSCLReleaseMinX: CGFloat = 0
    var nextBitClockSCLPullMinX: CGFloat = 0
    var nextBitClockEndMinX: CGFloat = 0
    var nextTransmissionStopSCLReleaseMinX: CGFloat = 0
    var nextTransmissionStopSDAReleaseMinX: CGFloat = 0
    var nextTransmissionStopEndMinX: CGFloat = 0
    
    
    init(onReadSuccess: (([UInt8])->())?) {
        
        self.onReadSuccess = onReadSuccess
    }
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }


    func printState() {

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
    
    
    override func initState(x: CGFloat) {
        
        currentX = x
        
        resetTransmissionState()
    }
    
    
    override func updateBusControl(after event: I2CBusEvent) {

        switch event {
        case .timeStep(let step):
            
            currentX += step
            
            if activeTransmission == nil {
                
                if let entry = scheduledTransmissions.sorted(by: { a, b in a.x < b.x }).first, entry.x <= currentX {
                    
                    scheduledTransmissions.removeAll(where: { $0.transmission.id == entry.transmission.id })
                    activeTransmission = entry.transmission
                    
                    resetTransmissionState()
                    printState()
                }
            }
            
        case .lineChange(let changedLine):
            
            if activeTransmission != nil {
                
                passiveTransmissionMonitor.update(
                    afterLineChange: changedLine,
                    onReadAddressByte: { _ in
                    },
                    onReadAddressAck: { ack in
                        switch ack {
                        case .ack:
                            addressAcked = true
                        case .nack:
                            sendingStop = true
                        }
                    },
                    onReadDataByte: { _ in
                    },
                    onReadDataAck: { ack in
                        if ack == .nack {
                            sendingStop = true
                        }
                    },
                    onReadBit: { bit in
                        prepareNextBit()
                        if nextBitToWrite == nil {
                            sendingStop = true
                        }
                    },
                    onDone: { readBytes in
                        let readSuccess = self.activeTransmission!.mode == .read && addressAcked
                        clearActiveTransmission()
                        printState()
                        if readSuccess {
                            onReadSuccess?(readBytes)
                        }
                    },
                    onAborted: {
                        clearActiveTransmission()
                        printState()
                    }
                )
                printState()
            }
            
            if activeTransmission != nil {
                
                updateDriveState()
                updateControls()
            }
            
            break
        }
        
        printState()
    }
    
    
    func clearActiveTransmission() {
        
        self.activeTransmission = nil
    }
    
    
    func resetTransmissionState() {
        
        passiveTransmissionMonitor.reset(lineLevels: bus.currentLineLevels)
        currentTransmissionDriveState = .start_releasingSDA
        
        sendingStop = false
        holdingBus = false
        addressAcked = false
        
        nextTransmissionStartSDAReleaseMinX = currentX + xWaitBeforeStartSDARelease
        
        prepareNextBit()
    }
    
    
    func updateDriveState() {
        
        switch currentTransmissionDriveState {
        
        case .start_waitingBeforeReleasingSDA:
            
            if passiveTransmissionMonitor.currentTransmissionState != .waitingStart {
                return
            }
            
            if currentX < nextTransmissionStartSDAReleaseMinX {
                return
            }
            
            currentTransmissionDriveState = .start_releasingSDA
            
        case .start_releasingSDA:
            
            if bus.lineSDA.isLow {
                return
            }
            
            currentTransmissionDriveState = .start_waitingBeforeReleasingSCL
            
        case .start_waitingBeforeReleasingSCL:
            
            if currentX < nextTransmissionStartSCLReleaseMinX {
                return
            }
            
            currentTransmissionDriveState = .start_releasingSCL
            
        case .start_releasingSCL:
            
            if bus.lineSCL.isHigh {
                return
            }
            
            currentTransmissionDriveState = .start_waitingBeforeSDADrop
            nextTransmissionStartSDAPullMinX = currentX + xWaitBeforeStartSDAPull
            
        case .start_waitingBeforeSDADrop:
            
            if currentX < nextTransmissionStartSDAPullMinX {
                return
            }
            
            currentTransmissionDriveState = .start_droppingSDA
            
        case .start_droppingSDA:
            
            if bus.lineSDA.isHigh {
                return
            }
            
            currentTransmissionDriveState = .start_waitingAfterSDADrop
//            nextBitSetupStartMinX = currentX + xWaitAfterStart
            
        case .start_waitingAfterSDADrop:
            
            if passiveTransmissionMonitor.currentTransmissionState != .started {
                return
            }
            
            if currentX < nextTransmissionStartEndMinX {
                return
            }
            
            currentTransmissionDriveState = .bitSetup_waitingBeforePullingSCL
            
        case .bitSetup_waitingBeforePullingSCL:
            
            if currentX < nextBitSetupSCLPullMinX {
                return
            } else {
                currentTransmissionDriveState = .bitSetup_pullingSCL
            }
            
        case .bitSetup_pullingSCL:
            
            if bus.lineSCL.isHigh {
                self.pullingSCL = true
            } else {
                currentTransmissionDriveState = .bitSetup_assertingSDA
//                nextBitClockStartMinX = currentX + xWaitBeforeBitClockHigh
            }
            
        case .bitSetup_waitingBeforeAssertingSDA:
            
            if currentX < nextBitSetupSDAAssertMinX {
                return
            } else {
                currentTransmissionDriveState = .bitSetup_assertingSDA
            }
            
        case .bitSetup_assertingSDA:
            
            if sendingStop {
                if bus.lineSDA.isHigh {
                    self.pullingSDA = true
                    return
                }
            } else if writingBit {
                if nextBitToWrite == .zero && bus.lineSDA.isHigh {
                    self.pullingSDA = true
                    return
                }
                if nextBitToWrite == .one && bus.lineSDA.isLow {
                    self.pullingSDA = false
                    return
                }
            } else {
                self.pullingSDA = false
            }
            
            currentTransmissionDriveState = .bitSetup_waitingBeforeBitClock
            
        case .bitSetup_waitingBeforeBitClock:
            
            if currentX < nextBitClockSCLReleaseMinX {
                return
            } else {
                currentTransmissionDriveState = .bitSetup_releasingSCL
            }
            
        case .bitSetup_releasingSCL:
            
            if bus.lineSCL.isLow {
                self.pullingSCL = false
            } else {
                if sendingStop {
                    currentTransmissionDriveState = .stop_waitingBeforeReleasingSDA
                    nextTransmissionStopSCLReleaseMinX = currentX + xWaitBeforeStop
                } else {
                    currentTransmissionDriveState = .bitClock_waitingDuringBitClock
                    nextBitClockEndMinX = currentX + xWaitDuringBitClockHigh
                }
            }
            
        case .bitClock_waitingDuringBitClock:
            
            if currentX < nextBitClockSCLPullMinX {
                return
            } else {
                currentTransmissionDriveState = .bitClock_pullingSCL
            }
            
        case .bitClock_pullingSCL:
            
            if bus.lineSCL.isHigh {
                self.pullingSCL = true
            } else {
                currentTransmissionDriveState = .bitClock_waitingAfterBitClock
//                nextBitSetupStartMinX = currentX + xWaitAfterBitClockHigh
//                nextBitClockStartMinX = nextBitSetupStartMinX + xWaitBeforeBitClockHigh
            }
            
        case .bitClock_waitingAfterBitClock:
            
            if currentX < nextBitClockEndMinX {
                return
            } else {
                currentTransmissionDriveState = .bitSetup_waitingBeforeAssertingSDA
            }
            
        case .stop_waitingBeforeReleasingSCL:
            
            if currentX < nextTransmissionStopSCLReleaseMinX {
                return
            } else {
                currentTransmissionDriveState = .stop_releasingSCL
            }
            
        case .stop_releasingSCL:
            break
            
        case .stop_waitingBeforeReleasingSDA:
            
            if currentX < nextTransmissionStopSDAReleaseMinX {
                return
            } else {
                currentTransmissionDriveState = .stop_releasingSDA
            }
            
        case .stop_releasingSDA:
            
            if bus.lineSDA.isHigh {
                self.pullingSDA = false
            } else {
                currentTransmissionDriveState = .stop_waitingAfterSDARelease
                nextTransmissionStopEndMinX = currentX + xWaitAfterStop
//                nextTransmissionStartSCLReleaseMinX = nextTransmissionStopEndMinX! + xWaitBeforeStartSCLRelease
            }
            
        case .stop_waitingAfterSDARelease:
            
            if currentX < nextTransmissionStopEndMinX {
                return
            } else {
                currentTransmissionDriveState = .start_waitingBeforeReleasingSDA
            }
        }
    }
    
    
    func updateControls() {
        
        switch currentTransmissionDriveState {
            
        case .start_waitingBeforeReleasingSDA:
            break
            
        case .start_releasingSDA:
            self.pullingSDA = false
            
        case .start_waitingBeforeReleasingSCL:
            break
            
        case .start_releasingSCL:
            self.pullingSCL = false
            
        case .start_waitingBeforeSDADrop:
            break
            
        case .start_droppingSDA:
            self.pullingSDA = true
            
        case .start_waitingAfterSDADrop:
            break
            
        case .bitSetup_waitingBeforePullingSCL:
            break
            
        case .bitSetup_pullingSCL:
            self.pullingSCL = true
            
        case .bitSetup_waitingBeforeAssertingSDA:
            break
            
        case .bitSetup_assertingSDA:
            self.pullingSDA = (writingBit && nextBitToWrite == .zero)
            
        case .bitSetup_waitingBeforeBitClock:
            break
            
        case .bitSetup_releasingSCL:
            self.pullingSCL = false
            
        case .bitClock_waitingDuringBitClock:
            break
            
        case .bitClock_pullingSCL:
            self.pullingSCL = true
            
        case .bitClock_waitingAfterBitClock:
            break
            
        case .stop_waitingBeforeReleasingSCL:
            break
            
        case .stop_releasingSCL:
            self.pullingSCL = false
        
        case .stop_waitingBeforeReleasingSDA:
            break
            
        case .stop_releasingSDA:
            self.pullingSDA = false
            
        case .stop_waitingAfterSDARelease:
            break
        }
    }


    private func prepareNextBit() {

        writingBit = false
        
        switch passiveTransmissionMonitor.currentTransmissionStep {
        
        case .transmittingAddressByte:
            
            writingBit = true
            nextBitToWrite = nextAddressBitToWrite
        
        case .transmittingAddressAck:
            break
            
        case .transmittingDataByte:
            
            if activeTransmission!.mode == .write {
                writingBit = true
                nextBitToWrite = nextDataBitToWrite
            }
        
        case .transmittingDataAck:
        
            if activeTransmission!.mode == .read {
                writingBit = true
                let ack = passiveTransmissionMonitor.currentByteIndex < activeTransmission!.numBytes-1
                nextBitToWrite = ack ? .zero : .one
            }
        }
    }


    var nextAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: passiveTransmissionMonitor.currentByteBitIndex)
    }


    var nextDataBitToWrite: Bit? {

        let byteIndex = passiveTransmissionMonitor.currentByteIndex
        if byteIndex < activeTransmission!.bytes.count {
            let byte = activeTransmission!.bytes[byteIndex]
            return byte.bit(atIndex: passiveTransmissionMonitor.currentByteBitIndex)
        } else {
            return nil
        }
    }
}
