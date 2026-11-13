
import SwiftUI



enum I2CStopFSMState {
    
    case ready
    case activated
    case pullingSDA
    case releasingSCL
    case waitingBefore
    case releasingSDA
    case waitingAfter
    case done
    case error
}


class I2CStopFSM {
    
    
    private(set) var currentState: I2CStopFSMState = .ready
    
    private let xWaitBeforeStop: CGFloat = 30
    private let xWaitAfterStop: CGFloat = 30
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
                currentState = .waitingBefore
            } else if updatedBusState == .transmitting_HL {
                currentState = .pullingSDA
            } else if updatedBusState == .transmitting_LL {
                currentState = .releasingSCL
            } else {
                currentState = .error
            }
        
        case .pullingSDA:

            if updatedBusState == .transmitting_LL {
                currentState = .releasingSCL
            } else if updatedBusState != .transmitting_HL {
                currentState = .error
            }

        case .releasingSCL:

            if updatedBusState == .transmitting_LH {
                currentState = .waitingBefore
            } else if updatedBusState != .transmitting_LL {
                currentState = .error
            }

        case .waitingBefore:

            if updatedBusState != .started_LH && updatedBusState != .transmitting_LH {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitBeforeStop {
                    currentState = .releasingSDA
                    xRef = nil
                }
            }

        case .releasingSDA:

            if updatedBusState == .idle_HH {
                currentState = .waitingAfter
            } else if updatedBusState != .started_LH && updatedBusState != .transmitting_LH {
                currentState = .error
            }

        case .waitingAfter:

            if updatedBusState != .idle_HH {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterStop {
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
