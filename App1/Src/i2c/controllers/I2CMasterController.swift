
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
    private var writeBitFSM = I2CWriteBitFSM()

    private var transmittingAddressRWByte: Int = 0

    private var lastMicroStateActedOn: I2CBusFSMMicroState?
    
    private let xWaitAfterStart: CGFloat = 30
    private let xWaitBeforeBitClockHigh: CGFloat = 30
    private let xWaitBitClockHigh: CGFloat = 100
    private let xWaitAfterBitClockHigh: CGFloat = 30
    private let xStepDefault: CGFloat = 30
    
    private var xRef: CGFloat?
    
    
    func schedule(_ transmission: I2CTransmission, at x: CGFloat) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }
    
    
    override func _compute(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        if self.activeTransmission == nil {

            activateNextTransmission(x: x)
        }
        
        if let transmission = activeTransmission {
            
            updateState(levelSCL: levelSCL, levelSDA: levelSDA, x: x)
            
            if transmissionFSM.currentState == .done {
                
                clearCurrentTransmission()
                
            } else {
                
                actOnState(levelSCL: levelSCL, levelSDA: levelSDA, x: x)
            }
        }
    }


    private func updateState(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {

        switch transmissionFSM.currentState {
                
        case .sendingStart:
            
            switch startStopFSM.currentState {
                
            case .preparingLines:
                
                if busFSM.currentMicroState == .idle_HH {
                    
                    startStopFSM.linesReady()

                } else {

                    // waiting for previous action to take effect
                }
                
            case .assertingLines:
                
                if busFSM.currentMicroState == .started {
                    
                    startStopFSM.linesAsserted()

                } else if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting for previous action to take effect

                } else {

                    abortCurrentTransmission()
                }

            case .waiting:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xWaitAfterStart {
                    
                    startStopFSM.waited()
                    xRef = nil
                }
                
            case .done:
                
                transmissionFSM.startSent()
                startStopFSM.reset()
            }
            
        case .sendingAddressRW:
            
            switch writeBitFSM.currentState {
                
            case .preparingLines:
                
                if busFSM.currentMicroState == .transmitting_LL {
                    
                    writeBitFSM.linesReady()

                } else if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting for previous action to take effect

                } else {

                    abortCurrentTransmission()
                }

            case .waitingLowBefore:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xWaitBeforeBitClockHigh {
                    
                    writeBitFSM.waitedLowBefore()
                    xRef = nil
                }
                
            case .clockingHigh:
                
                if busFSM.currentMicroState == .transmitting_LH {
                    
                    writeBitFSM.gotClockHigh()

                } else if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting for previous action to take effect

                } else {

                    abortCurrentTransmission()
                }
                
            case .waitingHigh:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xWaitBitClockHigh {
                    
                    writeBitFSM.waitedHigh()
                    xRef = nil
                }
                
            case .clockingLow:
                
                if busFSM.currentMicroState == .transmitting_LL {
                    
                    writeBitFSM.gotClockLow()

                } else if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting for previous action to take effect

                } else {

                    abortCurrentTransmission()
                }
                
            case .waitingLowAfter:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xWaitAfterBitClockHigh {
                    
                    writeBitFSM.waitedLowAfter()
                    xRef = nil
                }
                
            case .done:
                
                if transmittingAddressRWByte == 7 {

                    transmissionFSM.addressRWSent()

                } else {

                    transmittingAddressRWByte += 1
                }

                writeBitFSM.reset()
            }
            
        case .readingAddressAck:
            break
        
        case .readyData:
            break
        
        case .transmittingByte:
            break
        
        case .transmittingByteAck:
            break
        
        case .sendingStop:
            break
        
        case .done:

            transmissionFSM.reset()
            transmittingAddressRWByte = 0

            break
        }

        print("")
        print("-- UPDATED STATE --")
        print("bus state: \(busFSM.currentMicroState)")
        print("transmission: \(activeTransmission)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("start/stop state: \(startStopFSM.currentState)")
        print("bit state: \(writeBitFSM.currentState)")
    }


    private func actOnState(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {

        switch transmissionFSM.currentState {
                    
        case .sendingStart:
            
            switch startStopFSM.currentState {
                
            case .preparingLines:
                
                releaseSCL()
                releaseSDA()
                
            case .assertingLines:
                
                releaseSCL()
                pullSDALow()

            case .waiting:
                
                releaseSCL()
                pullSDALow()
                
            case .done:
                
                break
            }
            
        case .sendingAddressRW:
            
            switch writeBitFSM.currentState {
                
            case .preparingLines:
                
                pullSCLLow()
                pullSDALow()

            case .waitingLowBefore:
                
                pullSCLLow()
                pullSDALow()
                
            case .clockingHigh:
                
                pullSCLLow()
                releaseSCL()
                
            case .waitingHigh:
                
                pullSCLLow()
                releaseSCL()
                
            case .clockingLow:
                
                pullSCLLow()
                pullSDALow()
                
            case .waitingLowAfter:
                
                pullSCLLow()
                pullSDALow()
                
            case .done:
                
                break
            }
            
        case .readingAddressAck:
            break
            
        case .readyData:
            break
            
        case .transmittingByte:
            break
            
        case .transmittingByteAck:
            break
            
        case .sendingStop:
            break
            
        case .done:
            break
        }

        lastMicroStateActedOn = busFSM.currentMicroState
    }
    
    
    private func abortCurrentTransmission() {
        
        print("!! TRANSMISSION ABORTED !!\n")

        releaseSCL()
        releaseSDA()

        clearCurrentTransmission()
    }
    
    
    private func clearCurrentTransmission() {
        
        activeTransmission = nil
    }
    
    
    private func activateNextTransmission(x: CGFloat) {
        
        if let entry = self.scheduledTransmissions.first, entry.x <= x {
            
            _ = self.scheduledTransmissions.dropFirst()
            self.activeTransmission = entry.transmission
        }
    }
}
