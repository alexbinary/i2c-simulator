
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    let onReadSuccess: (([UInt8])->())?
    
    var scheduledTransmissions: [ScheduledTransmission] = []
    var activeTransmission: I2CTransmission? = nil
    var addressAcked: Bool = false

    var sendingStop = false
    var holdingBus = false
    var writingBit = false
    var nextBitToWrite: Bit = .zero
    
    var transmissionFSM = I2CTransmissionPassiveStateMachine()

    let xWaitBeforeStartSCLRelease: CGFloat = 10
    let xWaitBeforeStartSDAPull: CGFloat = 10
    let xWaitAfterStart: CGFloat = 10

    let xWaitBeforeBitClockHigh: CGFloat = 10
    let xWaitDuringBitClockHigh: CGFloat = 10
    let xWaitAfterBitClockHigh: CGFloat = 10

    let xWaitBeforeStop: CGFloat = 10
    let xWaitAfterStop: CGFloat = 100
    
    var currentX: CGFloat = 0
    var nextTransmissionStartReleasesSCLAfterX: CGFloat = 0
    var nextTransmissionStartPullsSDAAfterX: CGFloat = 0
    var nextBitSetupStartsAfterX: CGFloat = 0
    var nextBitClockHighStartsAfterX: CGFloat = 0
    var nextBitClockHighEndsAfterX: CGFloat = 0
    var transmissionStopStartsAfterX: CGFloat = 0
    var transmissionStopEndsAtX: CGFloat?
    
    
    init(
        onReadSuccess: (([UInt8])->())?
    ) {
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
                
                transmissionFSM.update(
                    afterLineChange: changedLine,
                    onBitClocked: onBitClocked,
                    onDone: onTransmissionDone,
                    onAborted: {
                        self.activeTransmission = nil
                        printState()
                    }
                )
                printState()
            }
            
            if activeTransmission != nil {
                updateControls()
            }
            
            break
        }
        
        printState()
    }
    
    
    func onTransmissionDone(readBytes: [UInt8]) {
        
        let readSuccess = self.activeTransmission!.mode == .read && addressAcked
        
        clearActiveTransmission()
        printState()
        
        if readSuccess {
            onReadSuccess?(readBytes)
        }
    }
    
    
    func updateControls() {
        
        switch transmissionFSM.currentMicroState {
        case .waitingIdle:
            
            if bus.lineSDA.isLow {
                self.pullingSDA = false
                return
            }
            
            if currentX < nextTransmissionStartReleasesSCLAfterX {
                return
            }
            
            if bus.lineSCL.isLow {
                self.pullingSCL = false
                return
            }
            
            nextTransmissionStartPullsSDAAfterX = currentX + xWaitBeforeStartSDAPull
            
        case .waitingSDADrop:
            
            if currentX < nextTransmissionStartPullsSDAAfterX {
                return
            }
            
            self.pullingSDA = true
            nextBitSetupStartsAfterX = currentX + xWaitAfterStart
            
        case .started:
            
            switch transmissionFSM.currentBitClockState {
            case .low:
                
                if currentX < nextBitSetupStartsAfterX {
                    return
                }
                
                if bus.lineSCL.isHigh {
                    self.pullingSCL = true
                    nextBitClockHighStartsAfterX = currentX + xWaitBeforeBitClockHigh
                    return
                }
                
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
                
                if currentX < nextBitClockHighStartsAfterX {
                    return
                }
                
                if holdingBus {
                    onTransmissionDone(readBytes: transmissionFSM.readDataBytes)
                } else {
                    self.pullingSCL = false
                    
                    nextBitClockHighEndsAfterX = currentX + xWaitDuringBitClockHigh
                    transmissionStopStartsAfterX = currentX + xWaitBeforeStop
                }
                
            case .high:
                
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

    
    func clearActiveTransmission() {
        
        self.activeTransmission = nil
    }
    
    
    func resetTransmissionState() {
        
        transmissionFSM.reset(lineLevels: bus.currentLineLevels)
        
        sendingStop = false
        holdingBus = false
        addressAcked = false
        
        nextTransmissionStartReleasesSCLAfterX = max(nextTransmissionStartReleasesSCLAfterX, currentX + xWaitBeforeStartSCLRelease)
        
        prepareNextBit()
    }


    func onBitClocked(bit: Bit, transmissionMacroState: I2CTransmissionPassiveStateMachine.MacroState, byteIndex: Int) {

        sendingStop = false
        holdingBus = false
        
        if transmissionMacroState == .transmittingAddressAck || transmissionMacroState == .transmittingDataAck {
            
            let ackBit = bit
            let ack = ackBit == .zero
            
            if ack && transmissionMacroState == .transmittingAddressAck {
                addressAcked = true
            }

            if !ack || byteIndex == (activeTransmission!.bytes.count-1) {
                sendingStop = true
//                holdingBus = true
            }
        }

        if !sendingStop {
            prepareNextBit()
        }
    }


    private func prepareNextBit() {

        writingBit = false
        
        switch transmissionFSM.currentMacroState {
        
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
                let ack = transmissionFSM.currentByteIndex < activeTransmission!.numBytes-1
                nextBitToWrite = ack ? .zero : .one
            }
        }
    }


    var nextAddressBitToWrite: Bit {

        let byte = activeTransmission!.addressRW
        return byte.bit(atIndex: transmissionFSM.currentByteBitIndex)
    }


    var nextDataBitToWrite: Bit {

        let byte = activeTransmission!.bytes[transmissionFSM.currentByteIndex]
        return byte.bit(atIndex: transmissionFSM.currentByteBitIndex)
    }
}
