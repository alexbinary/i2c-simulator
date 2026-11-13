
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil
    
    private var transmissionFSM = I2CTransmissionFSM()
    private var bitWriteFSM = I2CBitWriteFSM()
    private var bitReadFSM = I2CBitReadFSM()

    private var transmittingAddressRWBit: Int = 0
    private var currentTransmissionBit: Bit { Bit((Int(self.activeTransmission!.addressRW) >> (7-transmittingAddressRWBit)) & 1) }
    private var lastReadBit: Bit!
    
    private let xWaitBeforeStop: CGFloat = 30
    private let xWaitAfterStop: CGFloat = 0
    private let xWaitBeforeBitClockHigh: CGFloat = 30
    private let xWaitBitClockHigh: CGFloat = 100
    private let xWaitAfterBitClockHigh: CGFloat = 30
    private let xStepDefault: CGFloat = 30
    
    private var xRef: CGFloat?
    
    
    func scheduleTransmission(at x: CGFloat, _ transmission: I2CTransmission) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }


    private func printState() {

        print("")
        print("-- MASTER UPDATED STATE --")
        print("bus state: \(busFSM.currentState)")
        print("transmission: \(activeTransmission)")
        print("transmission state: \(transmissionFSM.currentState)")
        print("start/stop state: \(startStopFSM.currentState)")
        print("bit write state: \(bitWriteFSM.currentState)")
        print("transmittingAddressRWBit: \(transmittingAddressRWBit)")
        print("bit read state: \(bitReadFSM.currentState)")
    }
    
    
    override func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {

        if transmissionFSM.currentState == .done {
            clearCurrentTransmission()
            transmissionFSM.reset()
            transmittingAddressRWBit = 0
            printState()
        }

        if self.activeTransmission == nil {
            activateNextTransmission(x: x)
            printState()
        }

        if self.activeTransmission != nil {
            let action = updateTransmissionState(x: x)
            printState()
            if let action = action {
                return action
            }
        }

        return nil
    }


    private func updateTransmissionState(x: CGFloat) -> I2CControllerLineAction? {

        while true {

            switch transmissionFSM.currentState {  
            case .sendingStart:
                
                switch startStopFSM.currentState {
                case .ready:
                    startStopFSM.activate()

                case .pullingSDA:
                    return .pullSDALow

                case .done:
                    transmissionFSM.startSent()
                    startStopFSM.reset()
                    continue

                case .error:
                    abortTransmission()
                    startStopFSM.reset()

                default:
                    break
                }
                
            case .writingAddressRW:

                switch bitWriteFSM.currentState {
                case .pullingSCLLow:
                    
                    if busFSM.currentState == .started_LH || busFSM.currentState == .transmitting_LH  || busFSM.currentState == .transmitting_HH {
                        return .pullSCLLow
                    }
                    if busFSM.currentState == .transmitting_LL || busFSM.currentState == .transmitting_HL {
                        bitWriteFSM.SCLReady()
                        continue
                    }
                    abortTransmission()
                    return nil

                case .assertingSDA:

                    switch currentTransmissionBit {
                    case .zero:

                        if busFSM.currentState == .transmitting_HL {
                            return .pullSDALow
                        }
                        if busFSM.currentState == .transmitting_LL {
                            bitWriteFSM.SDAAsserted()
                            continue
                        }
                        abortTransmission()
                        return nil

                    case .one:

                        if busFSM.currentState == .transmitting_LL {
                            return .releaseSDA
                        }
                        if busFSM.currentState == .transmitting_HL {
                            bitWriteFSM.SDAAsserted()
                            continue
                        }
                        abortTransmission()
                        return nil
                    }

                case .waitingLowBefore:

                    switch currentTransmissionBit {
                    case .zero:

                        if busFSM.currentState != .transmitting_LL {
                            abortTransmission()
                            return nil
                        }

                    case .one:

                        if busFSM.currentState != .transmitting_HL {
                            abortTransmission()
                            return nil
                        }
                    }
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitBeforeBitClockHigh {
                        bitWriteFSM.waitedLowBefore()
                        xRef = nil
                    }
                    return nil
                    
                case .clockingHigh:

                    switch currentTransmissionBit {
                    case .zero:

                        if busFSM.currentState == .transmitting_LL {
                            return .releaseSCL
                        }
                        if busFSM.currentState == .transmitting_LH {
                            bitWriteFSM.gotClockHigh()
                            continue
                        }
                        abortTransmission()
                        return nil

                    case .one:

                        if busFSM.currentState == .transmitting_HL {
                            return .releaseSCL
                        }
                        if busFSM.currentState == .transmitting_HH {
                            bitWriteFSM.gotClockHigh()
                            continue
                        }
                        abortTransmission()
                        return nil
                    }
                    
                case .waitingHigh:

                    switch currentTransmissionBit {
                    case .zero:

                        if busFSM.currentState != .transmitting_LH {
                            abortTransmission()
                            return nil
                        }

                    case .one:

                        if busFSM.currentState != .transmitting_HH {
                            abortTransmission()
                            return nil
                        }
                    }
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitBitClockHigh {
                        bitWriteFSM.waitedHigh()
                        xRef = nil
                    }
                    return nil
                    
                case .clockingLow:

                    switch currentTransmissionBit {
                    case .zero:

                        if busFSM.currentState == .transmitting_LH {
                            return .pullSCLLow
                        }
                        if busFSM.currentState == .transmitting_LL {
                            bitWriteFSM.gotClockLow()
                            continue
                        }
                        abortTransmission()
                        return nil

                    case .one:

                        if busFSM.currentState == .transmitting_HH {
                            return .pullSCLLow
                        }
                        if busFSM.currentState == .transmitting_HL {
                            bitWriteFSM.gotClockLow()
                            continue
                        }
                        abortTransmission()
                        return nil
                    }

                case .waitingLowAfter:

                    switch currentTransmissionBit {
                    case .zero:

                        if busFSM.currentState != .transmitting_LL {
                            abortTransmission()
                            return nil
                        }

                    case .one:

                        if busFSM.currentState != .transmitting_HL {
                            abortTransmission()
                            return nil
                        }
                    }
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitAfterBitClockHigh {
                        bitWriteFSM.waitedLowAfter()
                        xRef = nil
                    }
                    return nil
                    
                case .done:
                    
                    if transmittingAddressRWBit == 7 {
                        transmissionFSM.addressRWSent()
                    } else {
                        transmittingAddressRWBit += 1
                    }
                    bitWriteFSM.reset()
                    continue
                }
                
            // case .readingAddressAck:

            //     switch bitReadFSM.currentState {
                    
            //     case .waitingLowBefore:

            //         if busFSM.currentState == .transmitting_LL {
            //             // ok
            //         } else if busFSM.currentState == .transmitting_HL {
            //             // ok
            //         } else {
            //             abortTransmission()
            //         }
            //         if xRef == nil {
            //             xRef = x
            //         }
            //         if x - xRef! >= xWaitBeforeBitClockHigh {
            //             bitReadFSM.waitedLowBefore()
            //             xRef = nil
            //         }
                    
            //     case .clockingHigh:
                    
            //         if busFSM.currentState == .transmitting_LH {
            //             bitReadFSM.gotClockHigh()
            //         } else if busFSM.currentState == .transmitting_HH {
            //             bitReadFSM.gotClockHigh()
            //         } else if busFSM.currentState == lastMicroStateActedOn {
            //             // waiting for previous action to take effect
            //         } else {
            //             abortTransmission()
            //         }
                    
            //     case .waitingHigh:

            //         if busFSM.currentState == .transmitting_LH {
            //             // ok
            //         } else if busFSM.currentState == .transmitting_HH {
            //             // ok
            //         } else {
            //             abortTransmission()
            //         }
            //         if xRef == nil {
            //             xRef = x
            //         }
            //         if x - xRef! >= xWaitBitClockHigh {
            //             bitReadFSM.waitedHigh()
            //             xRef = nil
            //         }

            //     case .reading:

            //         if busFSM.currentState == .transmitting_LH {
            //             lastReadBit = .zero
            //             bitReadFSM.readBit()
            //         } else if busFSM.currentState == .transmitting_HH {
            //             lastReadBit = .one
            //             bitReadFSM.readBit()
            //         } else {
            //             abortTransmission()
            //         }
                    
            //     case .clockingLow:

            //         if busFSM.currentState == .transmitting_LL {
            //             bitReadFSM.gotClockLow()
            //         } else if busFSM.currentState == .transmitting_HL {
            //             bitReadFSM.gotClockLow()
            //         } else if busFSM.currentState == lastMicroStateActedOn {
            //             // waiting for previous action to take effect
            //         } else {
            //             abortTransmission()
            //         }
                    
            //     case .waitingLowAfter:

            //         if busFSM.currentState == .transmitting_LL {
            //             // ok
            //         } else if busFSM.currentState == .transmitting_HL {
            //             // ok
            //         } else {
            //             abortTransmission()
            //         }
            //         if xRef == nil {
            //             xRef = x
            //         }
            //         if x - xRef! >= xWaitAfterBitClockHigh {
            //             bitReadFSM.waitedLowAfter()
            //             xRef = nil
            //         }
                    
            //     case .done:
                    
            //         if lastReadBit == .one {
            //             transmissionFSM.nack()
            //         } else {
            //             transmissionFSM.ack()
            //         }
            //         bitReadFSM.reset()
            //     }
            
            // case .readyData:
            //     break
            
            // case .transmittingByte:
            //     break
            
            // case .transmittingByteAck:
            //     break
            
            // case .sendingStop:
                
            //     switch startStopFSM.currentState {
                    
            //     case .preparingLines:
                    
            //         if busFSM.currentState == .transmitting_LH {
            //             startStopFSM.linesReady()
            //         }

            //     case .waitingBefore:

            //         if busFSM.currentState != .transmitting_LH {
            //             abortTransmission()
            //         }
            //         if xRef == nil {
            //             xRef = x
            //         }
            //         if x - xRef! >= xWaitBeforeStop {
            //             startStopFSM.waitedBefore()
            //             xRef = nil
            //         }
                    
            //     case .assertingLines:
                    
            //         if busFSM.currentState == .idle_HH {
            //             startStopFSM.linesAsserted()
            //         } else if busFSM.currentState == lastMicroStateActedOn {
            //             // waiting for previous action to take effect
            //         } else {
            //             abortTransmission()
            //         }

            //     case .waitingAfter:

            //         if busFSM.currentState != .idle_HH {
            //             abortTransmission()
            //         }
            //         if xRef == nil {
            //             xRef = x
            //         }
            //         if x - xRef! >= xWaitAfterStop {
            //             startStopFSM.waitedAfter()
            //             xRef = nil
            //         }
                    
            //     case .done:
                    
            //         transmissionFSM.stopSent()
            //         startStopFSM.reset()
            //     }
            
            case .done:
                break

            default:
                break
            }

            return nil
        }
    }


    // private func actOnTransmissionState(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {

    //     switch transmissionFSM.currentState {
                    
    //     case .sendingStart:
            
    //         switch startStopFSM.currentState {
                
    //         case .preparingLines:
    //             break

    //         case .waitingBefore:
    //             break

    //         case .assertingLines:
    //             pullSDALow()

    //         case .waitingAfter:
    //             pullSDALow()

    //         case .done:
    //             pullSDALow()
    //         }
            
    //     case .writingAddressRW:

    //         if currentTransmissionBit == .zero {
    //             pullSDALow()
    //         }

    //         switch bitWriteFSM.currentState {
                
    //         case .preparingLines:
    //             pullSCLLow()

    //         case .waitingLowBefore:
    //             pullSCLLow()
        
    //         case .clockingHigh:
    //             break
                
    //         case .waitingHigh:
    //             break
                
    //         case .clockingLow:
    //             pullSCLLow()
                
    //         case .waitingLowAfter:
    //             pullSCLLow()
                
    //         case .done:
    //             pullSCLLow()
    //         }
            
    //     case .readingAddressAck:
            
    //         switch bitReadFSM.currentState {
                
    //         case .waitingLowBefore:
    //             pullSCLLow()
        
    //         case .clockingHigh:
    //             break
                
    //         case .waitingHigh:
    //             break

    //         case .reading:
    //             break
                
    //         case .clockingLow:
    //             pullSCLLow()
                
    //         case .waitingLowAfter:
    //             pullSCLLow()
                
    //         case .done:
    //             pullSCLLow()
    //         }
            
    //     case .readyData:
    //         break
            
    //     case .transmittingByte:
    //         break
            
    //     case .transmittingByteAck:
    //         break
            
    //     case .sendingStop:
            
    //         switch startStopFSM.currentState {
                
    //         case .preparingLines:

    //             if busFSM.currentState == .transmitting_HH {
    //                 pullSCLLow()
    //             } else if busFSM.currentState == .transmitting_HL {
    //                 pullSCLLow()
    //                 pullSDALow()
    //             } else if busFSM.currentState == .transmitting_LL {
    //                 pullSDALow()
    //             } else if busFSM.currentState == .transmitting_LH {
    //                 // release everything => stop
    //             }

    //             // TODO wait between pulling SDA and releasing SCL

    //         case .waitingBefore:
    //             pullSDALow()

    //         case .assertingLines:
    //             break

    //         case .waitingAfter:
    //             break

    //         case .done:
    //             break
    //         }
            
    //     case .done:
    //         break
    //     }

    //     lastMicroStateActedOn = busFSM.currentState
    // }
    
    
    private func abortTransmission() {
        
        transmissionFSM.abort()
        
        print("-- !! TRANSMISSION ABORTED !! -- \n")
    }
    
    
    private func clearCurrentTransmission() {
        
        activeTransmission = nil

        print("-- TRANSMISSION COMPLETED -- \n")
    }
    
    
    private func activateNextTransmission(x: CGFloat) {
        
        if let entry = self.scheduledTransmissions.first, entry.x <= x {
            
            _ = self.scheduledTransmissions.removeFirst()
            self.activeTransmission = entry.transmission
        }
    }
}
