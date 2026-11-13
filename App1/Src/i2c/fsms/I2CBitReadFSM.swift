
import SwiftUI



enum I2CBitReadFSMState {
    
    case ready
    case activated
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
    
    
    var currentState: I2CBitReadFSMState = .ready

    private let xWaitBeforeBitClockHigh: CGFloat = 30
    private let xWaitBitClockHigh: CGFloat = 100
    private let xWaitAfterBitClockHigh: CGFloat = 30
    
    private var xRef: CGFloat?
    

    func reset() {

        currentState = .ready
    }
    

    func activate() {

        currentState = .activated
    }
    

    func update(x: CGFloat, updatedBusState: I2CBusFSMState) {

        switch currentState {

        case .ready:
            break

        case .activated:

            if updatedBusState == .started_LH {
                currentState = .pullingSCL
            } else if updatedBusState == .transmitting_HL {
                currentState = .waitingLowBefore
            } else if updatedBusState == .transmitting_LL {
                currentState = .waitingLowBefore
            } else {
                currentState = .error
            }
        
        case .pullingSCL:

            if updatedBusState == .transmitting_LL || updatedBusState == .transmitting_HL {
                currentState = .waitingLowBefore
            } else if updatedBusState != .started_LH {
                currentState = .error
            }
        
        case .waitingLowBefore:

            if updatedBusState != .transmitting_LL && updatedBusState != .transmitting_HL {
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

            if updatedBusState == .transmitting_LH || updatedBusState == .transmitting_HH {
                currentState = .waitingHigh
            } else if updatedBusState != .transmitting_LL && updatedBusState != .transmitting_HL {
                currentState = .error
            }
        
        case .waitingHigh:

            if updatedBusState != .transmitting_LH && updatedBusState != .transmitting_HH {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBitClockHigh {
                    currentState = .reading
                    xRef = nil
                }
            }
        
        case .reading:

            if updatedBusState == .transmitting_LH || updatedBusState == .transmitting_HH {
                currentState = .clockingLow
            } else {
                currentState = .error
            }
        
        case .clockingLow:

            if updatedBusState == .transmitting_LL || updatedBusState == .transmitting_HL {
                currentState = .waitingLowAfter
            } else if updatedBusState != .transmitting_LH && updatedBusState != .transmitting_HH {
                currentState = .error
            }
        
        case .waitingLowAfter:

            if updatedBusState != .transmitting_LL && updatedBusState != .transmitting_HL {
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

