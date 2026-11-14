
import SwiftUI



enum I2CBitWriteFSMState {
    
    case ready
    case activated
    case pullingSCL
    case pullingSDA
    case releasingSDA
    case waitingLowBefore
    case clockingHigh
    case waitingHigh
    case clockingLow
    case waitingLowAfter
    case done
    case error
}


class I2CBitWriteFSM {
    
    
    private(set) var currentState: I2CBitWriteFSMState = .ready

    private var sendingBit: Bit = .zero

    private let xWaitBeforeBitClockHigh: CGFloat = 30
    private let xWaitBitClockHigh: CGFloat = 100
    private let xWaitAfterBitClockHigh: CGFloat = 30
    
    private var xRef: CGFloat?


    func reset() {
        
        currentState = .ready
    }


    func activate(sending bit: Bit) {

        currentState = .activated
        sendingBit = bit
    }
    

    func update(x: CGFloat, updatedBusFSM: I2CBusFSM) {

        while true {

            var nextState = currentState

            switch currentState {

            case .ready:
                break

            case .activated:

                if updatedBusFSM.currentState == .started_LH {
                    nextState = .pullingSCL
                } else if sendingBit == .zero && updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .pullingSDA
                } else if sendingBit == .one && updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .releasingSDA
                } else {
                    nextState = .error
                }

            case .pullingSCL:

                if sendingBit == .zero && updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .waitingLowBefore
                } else if sendingBit == .one && updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .waitingLowBefore
                } else if sendingBit == .zero && updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .pullingSDA
                } else if sendingBit == .one && updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .releasingSDA
                } else if updatedBusFSM.currentState != .started_LH {
                    nextState = .error
                }

            case .pullingSDA:

                if updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .waitingLowBefore
                } else if updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                }

            case .releasingSDA:

                if updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .waitingLowBefore
                } else if updatedBusFSM.currentState != .transmitting_LL {
                    nextState = .error
                }

            case .waitingLowBefore:

                if sendingBit == .zero && updatedBusFSM.currentState != .transmitting_LL {
                    nextState = .error
                } else if sendingBit == .one && updatedBusFSM.currentState != .transmitting_HL {
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

                if sendingBit == .zero && updatedBusFSM.currentState == .transmitting_LH {
                    nextState = .waitingHigh
                } else if sendingBit == .one && updatedBusFSM.currentState == .transmitting_HH {
                    nextState = .waitingHigh
                } else if sendingBit == .zero && updatedBusFSM.currentState != .transmitting_LL {
                    nextState = .error
                } else if sendingBit == .one && updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                }

            case .waitingHigh:

                if sendingBit == .zero && updatedBusFSM.currentState != .transmitting_LH {
                    nextState = .error
                } else if sendingBit == .one && updatedBusFSM.currentState != .transmitting_HH {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitBitClockHigh {
                        nextState = .clockingLow
                        xRef = nil
                    }
                }

            case .clockingLow:

                if sendingBit == .zero && updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .waitingLowAfter
                } else if sendingBit == .one && updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .waitingLowAfter
                } else if sendingBit == .zero && updatedBusFSM.currentState != .transmitting_LH {
                    nextState = .error
                } else if sendingBit == .one && updatedBusFSM.currentState != .transmitting_HH {
                    nextState = .error
                }

            case .waitingLowAfter:

                if sendingBit == .zero && updatedBusFSM.currentState != .transmitting_LL {
                    nextState = .error
                } else if sendingBit == .one && updatedBusFSM.currentState != .transmitting_HL {
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

