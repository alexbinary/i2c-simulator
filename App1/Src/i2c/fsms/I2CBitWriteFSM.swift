
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
    
    
    var currentState: I2CBitWriteFSMState = .ready

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
    

    func update(x: CGFloat, updatedBusState: I2CBusFSMState) {

        switch currentState {

        case .ready:
            break

        case .activated:

            if updatedBusState == .started_LH {
                currentState = .pullingSCL
            } else if sendingBit == .zero && updatedBusState == .transmitting_HL {
                currentState = .pullingSDA
            } else if sendingBit == .one && updatedBusState == .transmitting_LL {
                currentState = .releasingSDA
            } else {
                currentState = .error
            }

        case .pullingSCL:

            if sendingBit == .zero && updatedBusState == .transmitting_LL {
                currentState = .waitingLowBefore
            } else if sendingBit == .one && updatedBusState == .transmitting_HL {
                currentState = .waitingLowBefore
            } else if sendingBit == .zero && updatedBusState == .transmitting_HL {
                currentState = .pullingSDA
            } else if sendingBit == .one && updatedBusState == .transmitting_LL {
                currentState = .releasingSDA
            } else if updatedBusState != .started_LH {
                currentState = .error
            }

        case .pullingSDA:

            if updatedBusState == .transmitting_LL {
                currentState = .waitingLowBefore
            } else if updatedBusState != .transmitting_HL {
                currentState = .error
            }

        case .releasingSDA:

            if updatedBusState == .transmitting_HL {
                currentState = .waitingLowBefore
            } else if updatedBusState != .transmitting_LL {
                currentState = .error
            }

        case .waitingLowBefore:

            if sendingBit == .zero && updatedBusState != .transmitting_LL {
                currentState = .error
            } else if sendingBit == .one && updatedBusState != .transmitting_HL {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBeforeBitClockHigh {
                    currentState = .clockingHigh
                    xRef = nil
                }
            }

        case .clockingHigh:

            if sendingBit == .zero && updatedBusState == .transmitting_LH {
                currentState = .waitingHigh
            } else if sendingBit == .one && updatedBusState == .transmitting_HH {
                currentState = .waitingHigh
            } else if sendingBit == .zero && updatedBusState != .transmitting_LL {
                currentState = .error
            } else if sendingBit == .one && updatedBusState != .transmitting_HL {
                currentState = .error
            }

        case .waitingHigh:

            if sendingBit == .zero && updatedBusState != .transmitting_LH {
                currentState = .error
            } else if sendingBit == .one && updatedBusState != .transmitting_HH {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBitClockHigh {
                    currentState = .clockingLow
                    xRef = nil
                }
            }

        case .clockingLow:

            if sendingBit == .zero && updatedBusState == .transmitting_LL {
                currentState = .waitingLowAfter
            } else if sendingBit == .one && updatedBusState == .transmitting_HL {
                currentState = .waitingLowAfter
            } else if sendingBit == .zero && updatedBusState != .transmitting_LH {
                currentState = .error
            } else if sendingBit == .one && updatedBusState != .transmitting_HH {
                currentState = .error
            }

        case .waitingLowAfter:

            if sendingBit == .zero && updatedBusState != .transmitting_LL {
                currentState = .error
            } else if sendingBit == .one && updatedBusState != .transmitting_HL {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterBitClockHigh {
                    currentState = .done
                    xRef = nil
                }
            }

        case .done:
            break

        case .error:
            break
        }
    }
}

