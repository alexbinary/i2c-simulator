
import SwiftUI



enum I2CMasterTransmissionFSMState {
    
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
    
    
    private(set) var currentState: I2CMasterTransmissionFSMState = .sendingStart
    private(set) var result: I2CMasterTransmissionResultEnum = .success

    var transmission: I2CTransmission

    private(set) var transmittingAddressRWBit: Int = 0
    private var currentTransmissionBit: Bit { Bit((Int(transmission.addressRW) >> (7-transmittingAddressRWBit)) & 1) }

    var sendStartFSM = I2CSendStartFSM()
    var sendStopFSM = I2CSendStopFSM()
    var bitWriteFSM = I2CBitWriteFSM()
    var bitReadFSM = I2CBitReadFSM()


    init(
        transmission: I2CTransmission
    ) {
        self.transmission = transmission
    }
    
    
    func reset() {
        
        currentState = .sendingStart
        result = .success

        sendStartFSM.reset()
        sendStopFSM.reset()
        bitWriteFSM.reset()
        bitReadFSM.reset()
    }


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM) {

        while true {

            var nextState = currentState

            switch currentState {
            case .sendingStart:

                sendStartFSM.update(x: x, updatedBusFSM: updatedBusFSM)
                
                switch sendStartFSM.currentState {
                case .done:
                    nextState = .writingAddressRW
                    sendStartFSM.reset()
                case .error:
                    nextState = .aborted
                    sendStartFSM.reset()
                default:
                    break
                }
                
            case .writingAddressRW:

                bitWriteFSM.sendingBit = currentTransmissionBit
                bitWriteFSM.update(x: x, updatedBusFSM: updatedBusFSM)
                
                switch bitWriteFSM.currentState {
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

                bitReadFSM.update(x: x, updatedBusFSM: updatedBusFSM)

                switch bitReadFSM.currentState {
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

                sendStopFSM.update(x: x, updatedBusFSM: updatedBusFSM)
                
                switch sendStopFSM.currentState {
                case .done:
                    nextState = .done
                    sendStopFSM.reset()
                case .error:
                    nextState = .aborted
                    sendStopFSM.reset()
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
}
