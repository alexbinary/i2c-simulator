
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

    private var lastMicroStateActedOn: I2CBusFSMMicroState?
    
    private let xStepAfterStart: CGFloat = 30
    private let xStepBitClockHigh: CGFloat = 100
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
                }
                
            case .assertingLines:
                
                if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting action to take effect

                } else if busFSM.currentMicroState == .started {
                    
                    startStopFSM.linesAsserted()

                } else {

                    abortCurrentTransmission()
                }

            case .waiting:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xStepAfterStart {
                    
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
                
                if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting action to take effect

                } else if busFSM.currentMicroState == .transmitting_LL {
                    
                    writeBitFSM.linesReady()

                } else {

                    abortCurrentTransmission()
                }
                
            case .clockingHigh:
                
                if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting action to take effect

                } else if busFSM.currentMicroState == .transmitting_LH {
                    
                    writeBitFSM.gotClockHigh()

                } else {

                    abortCurrentTransmission()
                }
                
            case .waitingHigh:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xStepBitClockHigh {
                    
                    writeBitFSM.waitedHigh()
                    xRef = nil
                }
                
            case .clockingLow:
                
                if busFSM.currentMicroState == lastMicroStateActedOn {

                    // waiting action to take effect

                } else if busFSM.currentMicroState == .transmitting_LL {
                    
                    writeBitFSM.gotClockHigh()

                } else {

                    abortCurrentTransmission()
                }
                
            case .waitingLow:
                
                if xRef == nil {
                    xRef = x
                }
                
                if x - xRef! >= xStepDefault {
                    
                    writeBitFSM.waitedLow()
                    xRef = nil
                }
                
            case .done:
                
                transmissionFSM.addressRWSent()
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
                
            case .clockingHigh:
                
                pullSCLLow()
                releaseSCL()
                
            case .waitingHigh:
                
                pullSCLLow()
                releaseSCL()
                
            case .clockingLow:
                
                pullSCLLow()
                pullSDALow()
                
            case .waitingLow:
                
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
