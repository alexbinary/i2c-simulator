
import SwiftUI



enum I2CBitReadFSMState {
    
    case ready
    case pullingSCL
    case waitingLowBefore
    case clockingHigh
    case waitingHigh
    case reading
    case clockingLow
    case waitingLowAfter
    case done
    case error
}


class I2CBitReadFSM {
    
    
    private(set) var currentState: I2CBitReadFSMState = .ready
    private(set) var readBit: Bit!

    private let xWaitBeforeBitClockHigh: CGFloat = 30
    private let xWaitBitClockHigh: CGFloat = 100
    private let xWaitAfterBitClockHigh: CGFloat = 30
    
    private var xRef: CGFloat?
    
    

    func reset() {

        currentState = .ready
    }
    

    func update(x: CGFloat, updatedBusFSM: I2CBusFSM) {

        while true {

            var nextState = currentState

            switch currentState {
            case .ready:

                if updatedBusFSM.currentState == .started_LH {
                    nextState = .pullingSCL
                } else if updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .waitingLowBefore
                } else if updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .waitingLowBefore
                } else {
                    nextState = .error
                }
            
            case .pullingSCL:

                if updatedBusFSM.currentState == .transmitting_LL || updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .waitingLowBefore
                } else if updatedBusFSM.currentState != .started_LH {
                    nextState = .error
                }
            
            case .waitingLowBefore:

                if updatedBusFSM.currentState != .transmitting_LL && updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitBeforeBitClockHigh {
                        nextState = .clockingHigh
                        xRef = nil
                    }
                }
            
            case .clockingHigh:

                if updatedBusFSM.currentState == .transmitting_LH || updatedBusFSM.currentState == .transmitting_HH {
                    nextState = .waitingHigh
                } else if updatedBusFSM.currentState != .transmitting_LL && updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                }
            
            case .waitingHigh:

                if updatedBusFSM.currentState != .transmitting_LH && updatedBusFSM.currentState != .transmitting_HH {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitBitClockHigh {
                        nextState = .reading
                        xRef = nil
                    }
                }
            
            case .reading:

                if updatedBusFSM.currentState == .transmitting_LH {
                    nextState = .clockingLow
                    readBit = .zero
                } else if updatedBusFSM.currentState == .transmitting_HH {
                    nextState = .clockingLow
                    readBit = .one
                } else {
                    nextState = .error
                }
            
            case .clockingLow:

                if updatedBusFSM.currentState == .transmitting_LL || updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .waitingLowAfter
                } else if updatedBusFSM.currentState != .transmitting_LH && updatedBusFSM.currentState != .transmitting_HH {
                    nextState = .error
                }
            
            case .waitingLowAfter:

                if updatedBusFSM.currentState != .transmitting_LL && updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitAfterBitClockHigh {
                        nextState = .done
                        xRef = nil
                    }
                }
            
            case .done:
                break
            
            case .error:
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

