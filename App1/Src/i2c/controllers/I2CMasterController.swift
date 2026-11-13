
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil
    
    private var transmissionFSM = I2CTransmissionFSM()

    private var transmittingAddressRWBit: Int = 0
    private var currentTransmissionBit: Bit { Bit((Int(self.activeTransmission!.addressRW) >> (7-transmittingAddressRWBit)) & 1) }
    private var lastReadBit: Bit!
    
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
        print("start state: \(startFSM.currentState)")
        print("stop state: \(stopFSM.currentState)")
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
                
                switch startFSM.currentState {
                case .ready:
                    startFSM.activate()

                case .pullingSDA:
                    return .pullSDA

                case .done:
                    transmissionFSM.startSent()
                    startFSM.reset()
                    continue

                case .error:
                    abortTransmission()
                    startFSM.reset()

                default:
                    break
                }
                
            case .writingAddressRW:

                switch bitWriteFSM.currentState {
                case .ready:
                    bitWriteFSM.activate(sending: currentTransmissionBit)

                case .pullingSCL, .clockingLow:
                    return .pullSCL

                case .pullingSDA:
                    return .pullSDA

                case .releasingSDA:
                    return .releaseSDA

                case .clockingHigh:
                    return .releaseSCL
                    
                case .done:
                    
                    if transmittingAddressRWBit == 7 {
                        transmissionFSM.addressRWSent()
                    } else {
                        transmittingAddressRWBit += 1
                    }
                    bitWriteFSM.reset()
                    continue

                case .error:
                    abortTransmission()
                    bitWriteFSM.reset()

                default:
                    break
                }
                
            case .readingAddressAck:

                switch bitReadFSM.currentState {
                    
                case .ready:
                    bitReadFSM.activate()

                case .pullingSCL, .clockingLow:
                    return .pullSCL

                case .clockingHigh:
                    return .releaseSCL

                case .reading:
            
                    if busFSM.currentState == .transmitting_HH {
                        lastReadBit = .one
                    } else if busFSM.currentState == .transmitting_LH {
                        lastReadBit = .zero
                    }

                case .done:
                    
                    if lastReadBit == .one {
                        transmissionFSM.nack()
                    } else {
                        transmissionFSM.ack()
                    }
                    bitReadFSM.reset()

                case .error:
                    abortTransmission()
                    bitReadFSM.reset()

                default:
                    break
                }
            
            // case .readyData:
            //     break
            
            // case .transmittingByte:
            //     break
            
            // case .transmittingByteAck:
            //     break
            
            case .sendingStop:
                
                switch stopFSM.currentState {
                case .ready:
                    stopFSM.activate()

                case .pullingSDA:
                    return .pullSDA

                case .releasingSCL:
                    return .releaseSCL

                case .releasingSDA:
                    return .releaseSDA
                    
                case .done:
                    transmissionFSM.stopSent()
                    stopFSM.reset()

                case .error:
                    abortTransmission()
                    stopFSM.reset()

                default:
                    break
                }
            
            case .done:
                break

            default:
                break
            }

            return nil
        }
    }
    
    
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
