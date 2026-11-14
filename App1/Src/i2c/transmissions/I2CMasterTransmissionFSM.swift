
import SwiftUI



enum I2CMasterTransmissionFSMState {
    
    case waitingXStart
    case sendingStart
    case writingAddressRW
    case readingAddressAck
    case readyData
    case transmittingByte
    case transmittingByteAck
    case sendingStop
    case done
    case aborted
}


enum I2CMasterTransmissionResultEnum {
    case success
    case addressNack
}


class I2CMasterTransmissionFSM {
    
    
    private(set) var currentState: I2CMasterTransmissionFSMState = .waitingXStart
    private(set) var result: I2CMasterTransmissionResultEnum = .success

    var transmission: I2CTransmission
    var xStart: CGFloat

    private(set) var transmittingAddressRWBit: Int = 0
    private var currentTransmissionBit: Bit { Bit((Int(transmission.addressRW) >> (7-transmittingAddressRWBit)) & 1) }

    var startFSM = I2CSendStartFSM()
    var stopFSM = I2CSendStopFSM()
    var bitWriteFSM = I2CBitWriteFSM()
    var bitReadFSM = I2CBitReadFSM()


    init(
        transmission: I2CTransmission,
        xStart: CGFloat
    ) {
        self.transmission = transmission
        self.xStart = xStart
    }
    
    
    func reset() {
        
        currentState = .waitingXStart
        result = .success

        startFSM.reset()
        stopFSM.reset()
        bitWriteFSM.reset()
        bitReadFSM.reset()
    }


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM) {

        startFSM.update(x: x, updatedBusFSM: updatedBusFSM)
        stopFSM.update(x: x, updatedBusFSM: updatedBusFSM)
        bitWriteFSM.update(x: x, updatedBusFSM: updatedBusFSM)
        bitReadFSM.update(x: x, updatedBusFSM: updatedBusFSM)

        while true {

            var nextState = currentState

            switch currentState {
            case .waitingXStart:

                if x >= xStart {
                    nextState = .sendingStart
                }

            case .sendingStart:
                
                switch startFSM.currentState {
                case .ready:
                    startFSM.activate()

                case .done:
                    nextState = .writingAddressRW
                    startFSM.reset()

                case .error:
                    nextState = .aborted
                    startFSM.reset()

                default:
                    break
                }
                
            case .writingAddressRW:

                switch bitWriteFSM.currentState {
                case .ready:
                    bitWriteFSM.activate(sending: currentTransmissionBit)
    
                case .done:
                    
                    if transmittingAddressRWBit == 7 {
                        nextState = .readingAddressAck
                    } else {
                        transmittingAddressRWBit += 1
                    }
                    bitWriteFSM.reset()

                case .error:
                    nextState = .aborted
                    bitWriteFSM.reset()

                default:
                    break
                }
                
            case .readingAddressAck:

                switch bitReadFSM.currentState {
                    
                case .ready:
                    bitReadFSM.activate()

                case .done:
                    
                    if bitReadFSM.readBit == .one {
                        nextState = .sendingStop
                    } else {
                        nextState = .readyData
                    }
                    bitReadFSM.reset()

                case .error:
                    nextState = .aborted
                    bitReadFSM.reset()

                default:
                    break
                }
            
            case .readyData:
                nextState = .sendingStop
            
            case .transmittingByte:
                break
            
            case .transmittingByteAck:
                break
            
            case .sendingStop:
                
                switch stopFSM.currentState {
                case .ready:
                    stopFSM.activate()
    
                case .done:
                    nextState = .done
                    stopFSM.reset()

                case .error:
                    nextState = .aborted
                    stopFSM.reset()

                default:
                    break
                }
                
            case .done:
                break

            case .aborted:
                break
            }

            if nextState != currentState {
                currentState = nextState
                continue
            } else {
                break
            }
        }
    }


    var currentAction: I2CControllerLineAction? {

        switch startFSM.currentState {
        case .pullingSDA:
            return .pullSDA

        default:
            break
        }

        switch bitWriteFSM.currentState {
        case .pullingSCL, .clockingLow:
            return .pullSCL

        case .pullingSDA:
            return .pullSDA

        case .releasingSDA:
            return .releaseSDA

        case .clockingHigh:
            return .releaseSCL
            
        default:
            break
        }

        switch bitReadFSM.currentState {
        case .pullingSCL, .clockingLow:
            return .pullSCL

        case .clockingHigh:
            return .releaseSCL

        default:
            break
        }

        switch stopFSM.currentState {
        case .pullingSDA:
            return .pullSDA

        case .releasingSCL:
            return .releaseSCL

        case .releasingSDA:
            return .releaseSDA
            
        default:
            break
        }

        return nil
    }
}
