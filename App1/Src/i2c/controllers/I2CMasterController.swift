
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil
    
    private var transmissionFSM = I2CTransmissionFSM()
    private var startStopFSM = I2CStartStopFSM()
    private var bitWriteFSM = I2CBitWriteFSM()
    private var bitReadFSM = I2CBitReadFSM()

    private var transmittingAddressRWBit: Int = 0
    private var currentTransmissionBit: Bit { Bit((Int(self.activeTransmission!.addressRW) >> (7-transmittingAddressRWBit)) & 1) }
    private var lastReadBit: Bit!

    private var lastMicroStateActedOn: I2CBusFSMMicroState?
    
    private let xWaitBeforeStart: CGFloat = 0
    private let xWaitAfterStart: CGFloat = 30
    private let xWaitBeforeStop: CGFloat = 30
    private let xWaitAfterStop: CGFloat = 0
    private let xWaitBeforeBitClockHigh: CGFloat = 30
    private let xWaitBitClockHigh: CGFloat = 100
    private let xWaitAfterBitClockHigh: CGFloat = 30
    private let xStepDefault: CGFloat = 30
    
    private var xRef: CGFloat?
    
    
    func schedule(_ transmission: I2CTransmission, at x: CGFloat) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }
    
    
    override func _compute(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        releaseSDA()
        releaseSCL()

        if self.activeTransmission == nil {
            activateNextTransmission(x: x)
        }
        
        if self.activeTransmission != nil {
            updateTransmissionState(levelSCL: levelSCL, levelSDA: levelSDA, x: x)
            
            if transmissionFSM.currentState == .done {
                clearCurrentTransmission()
            } else {
                actOnTransmissionState(levelSCL: levelSCL, levelSDA: levelSDA, x: x)
            }
        }
    }


    private func updateTransmissionState(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {

        switch transmissionFSM.currentState {
                
        case .sendingStart:
            
            switch startStopFSM.currentState {
                
            case .preparingLines:
                
                if busFSM.currentMicroState == .idle_HH {
                    startStopFSM.linesReady()
                }

            case .waitingBefore:

                if busFSM.currentMicroState != .idle_HH {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBeforeStart {
                    startStopFSM.waitedBefore()
                    xRef = nil
                }
                
            case .assertingLines:
                
                if busFSM.currentMicroState == .started {
                    startStopFSM.linesAsserted()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }

            case .waitingAfter:

                if busFSM.currentMicroState != .started {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterStart {
                    startStopFSM.waitedAfter()
                    xRef = nil
                }
                
            case .done:
                
                transmissionFSM.startSent()
                startStopFSM.reset()
            }
            
        case .writingAddressRW:
            
            switch bitWriteFSM.currentState {
                
            case .preparingLines:
                
                let targetMicroState: I2CBusFSMMicroState = currentTransmissionBit == .zero ? .transmitting_LL : .transmitting_HL
                if busFSM.currentMicroState == targetMicroState {
                    bitWriteFSM.linesReady()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }

            case .waitingLowBefore:

                let targetMicroState: I2CBusFSMMicroState = currentTransmissionBit == .zero ? .transmitting_LL : .transmitting_HL
                if busFSM.currentMicroState != targetMicroState {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBeforeBitClockHigh {
                    bitWriteFSM.waitedLowBefore()
                    xRef = nil
                }
                
            case .clockingHigh:
                
                let targetMicroState: I2CBusFSMMicroState = currentTransmissionBit == .zero ? .transmitting_LH : .transmitting_HH
                if busFSM.currentMicroState == targetMicroState {
                    bitWriteFSM.gotClockHigh()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }
                
            case .waitingHigh:

                let targetMicroState: I2CBusFSMMicroState = currentTransmissionBit == .zero ? .transmitting_LH : .transmitting_HH
                if busFSM.currentMicroState != targetMicroState {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBitClockHigh {
                    bitWriteFSM.waitedHigh()
                    xRef = nil
                }
                
            case .clockingLow:

                let targetMicroState: I2CBusFSMMicroState = currentTransmissionBit == .zero ? .transmitting_LL : .transmitting_HL
                if busFSM.currentMicroState == targetMicroState {
                    bitWriteFSM.gotClockLow()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }
                
            case .waitingLowAfter:

                let targetMicroState: I2CBusFSMMicroState = currentTransmissionBit == .zero ? .transmitting_LL : .transmitting_HL
                if busFSM.currentMicroState != targetMicroState {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterBitClockHigh {
                    bitWriteFSM.waitedLowAfter()
                    xRef = nil
                }
                
            case .done:
                
                if transmittingAddressRWBit == 7 {
                    transmissionFSM.addressRWSent()
                } else {
                    transmittingAddressRWBit += 1
                }
                bitWriteFSM.reset()
            }
            
        case .readingAddressAck:

            switch bitReadFSM.currentState {
                
            case .waitingLowBefore:

                if busFSM.currentMicroState == .transmitting_LL {
                    // ok
                } else if busFSM.currentMicroState == .transmitting_HL {
                    // ok
                } else {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBeforeBitClockHigh {
                    bitReadFSM.waitedLowBefore()
                    xRef = nil
                }
                
            case .clockingHigh:
                
                if busFSM.currentMicroState == .transmitting_LH {
                    bitReadFSM.gotClockHigh()
                } else if busFSM.currentMicroState == .transmitting_HH {
                    bitReadFSM.gotClockHigh()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }
                
            case .waitingHigh:

                if busFSM.currentMicroState == .transmitting_LH {
                    // ok
                } else if busFSM.currentMicroState == .transmitting_HH {
                    // ok
                } else {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBitClockHigh {
                    bitReadFSM.waitedHigh()
                    xRef = nil
                }

            case .reading:

                if busFSM.currentMicroState == .transmitting_LH {
                    lastReadBit = .zero
                    bitReadFSM.readBit()
                } else if busFSM.currentMicroState == .transmitting_HH {
                    lastReadBit = .one
                    bitReadFSM.readBit()
                } else {
                    abortTransmission()
                }
                
            case .clockingLow:

                if busFSM.currentMicroState == .transmitting_LL {
                    bitReadFSM.gotClockLow()
                } else if busFSM.currentMicroState == .transmitting_HL {
                    bitReadFSM.gotClockLow()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }
                
            case .waitingLowAfter:

                if busFSM.currentMicroState == .transmitting_LL {
                    // ok
                } else if busFSM.currentMicroState == .transmitting_HL {
                    // ok
                } else {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterBitClockHigh {
                    bitReadFSM.waitedLowAfter()
                    xRef = nil
                }
                
            case .done:
                
                if lastReadBit == .one {
                    transmissionFSM.nack()
                } else {
                    transmissionFSM.ack()
                }
                bitReadFSM.reset()
            }
        
        case .readyData:
            break
        
        case .transmittingByte:
            break
        
        case .transmittingByteAck:
            break
        
        case .sendingStop:
            
            switch startStopFSM.currentState {
                
            case .preparingLines:
                
                if busFSM.currentMicroState == .transmitting_LH {
                    startStopFSM.linesReady()
                }

            case .waitingBefore:

                if busFSM.currentMicroState != .transmitting_LH {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBeforeStop {
                    startStopFSM.waitedBefore()
                    xRef = nil
                }
                
            case .assertingLines:
                
                if busFSM.currentMicroState == .idle_HH {
                    startStopFSM.linesAsserted()
                } else if busFSM.currentMicroState == lastMicroStateActedOn {
                    // waiting for previous action to take effect
                } else {
                    abortTransmission()
                }

            case .waitingAfter:

                if busFSM.currentMicroState != .idle_HH {
                    abortTransmission()
                }
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterStop {
                    startStopFSM.waitedAfter()
                    xRef = nil
                }
                
            case .done:
                
                transmissionFSM.stopSent()
                startStopFSM.reset()
            }
        
        case .done:

            transmissionFSM.reset()
            transmittingAddressRWBit = 0

            break
        }

        print("")
        print("-- UPDATED STATE --")
        print("bus state: \(busFSM.currentMicroState)")
        print("transmission: \(activeTransmission)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("start/stop state: \(startStopFSM.currentState)")
        print("bit write state: \(bitWriteFSM.currentState)")
        print("bit read state: \(bitReadFSM.currentState)")
        print("transmittingAddressRWBit: \(transmittingAddressRWBit)")
    }


    private func actOnTransmissionState(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {

        switch transmissionFSM.currentState {
                    
        case .sendingStart:
            
            switch startStopFSM.currentState {
                
            case .preparingLines:
                break

            case .waitingBefore:
                break

            case .assertingLines:
                pullSDALow()

            case .waitingAfter:
                pullSDALow()

            case .done:
                pullSDALow()
            }
            
        case .writingAddressRW:

            if currentTransmissionBit == .zero {
                pullSDALow()
            }

            switch bitWriteFSM.currentState {
                
            case .preparingLines:
                pullSCLLow()

            case .waitingLowBefore:
                pullSCLLow()
        
            case .clockingHigh:
                break
                
            case .waitingHigh:
                break
                
            case .clockingLow:
                pullSCLLow()
                
            case .waitingLowAfter:
                pullSCLLow()
                
            case .done:
                pullSCLLow()
            }
            
        case .readingAddressAck:
            
            switch bitReadFSM.currentState {
                
            case .waitingLowBefore:
                pullSCLLow()
        
            case .clockingHigh:
                break
                
            case .waitingHigh:
                break

            case .reading:
                break
                
            case .clockingLow:
                pullSCLLow()
                
            case .waitingLowAfter:
                pullSCLLow()
                
            case .done:
                pullSCLLow()
            }
            
        case .readyData:
            break
            
        case .transmittingByte:
            break
            
        case .transmittingByteAck:
            break
            
        case .sendingStop:
            
            switch startStopFSM.currentState {
                
            case .preparingLines:

                if busFSM.currentMicroState == .transmitting_HH {
                    pullSCLLow()
                } else if busFSM.currentMicroState == .transmitting_HL {
                    pullSCLLow()
                    pullSDALow()
                } else if busFSM.currentMicroState == .transmitting_LL {
                    pullSDALow()
                } else if busFSM.currentMicroState == .transmitting_LH {
                    // release everything => stop
                }

                // TODO wait between pulling SDA and releasing SCL

            case .waitingBefore:
                pullSDALow()

            case .assertingLines:
                break

            case .waitingAfter:
                break

            case .done:
                break
            }
            
        case .done:
            break
        }

        lastMicroStateActedOn = busFSM.currentMicroState
    }
    
    
    private func abortTransmission() {
        
        transmissionFSM.abort()
        
        print("!! TRANSMISSION ABORTED !!\n")
    }
    
    
    private func clearCurrentTransmission() {
        
        activeTransmission = nil
    }
    
    
    private func activateNextTransmission(x: CGFloat) {
        
        if let entry = self.scheduledTransmissions.first, entry.x <= x {
            
            _ = self.scheduledTransmissions.removeFirst()
            self.activeTransmission = entry.transmission
        }
    }
}
