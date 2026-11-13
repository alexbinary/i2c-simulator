
import SwiftUI



enum I2CStartFSMState {
    
    case ready
    case activated
    case releasingSCL
    case releasingSDA
    case waitingBefore
    case pullingSDA
    case waitingAfter
    case done
    case error
}


class I2CStartFSM {
    
    
    private(set) var currentState: I2CStartFSMState = .ready
    
    private let xWaitBeforeStart: CGFloat = 30
    private let xWaitAfterStart: CGFloat = 30
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

            if updatedBusState == .idle_HH {
                currentState = .waitingBefore
            } else if updatedBusState == .idle_LL {
                currentState = .releasingSDA
            } else if updatedBusState == .idle_LH {
                currentState = .releasingSDA
            } else if updatedBusState == .idle_HL {
                currentState = .releasingSCL
            } else if updatedBusState == .transmitting_HL {
                currentState = .releasingSCL
            } else if updatedBusState == .transmitting_LL {
                currentState = .releasingSDA
            } else {
                currentState = .error
            }

        case .releasingSCL:

            if updatedBusState == .idle_HH || updatedBusState == .transmitting_HH {
                currentState = .waitingBefore
            } else if updatedBusState != .idle_HL && updatedBusState != .transmitting_HL {
                currentState = .error
            }

        case .releasingSDA:

            if updatedBusState != .idle_HL {
                currentState = .releasingSCL
            } else if updatedBusState != .idle_HH {
                currentState = .waitingBefore
            } else if updatedBusState != .transmitting_HL {
                currentState = .releasingSCL
            } else if updatedBusState != .idle_LL && updatedBusState != .idle_LH && updatedBusState != .transmitting_LL {
                currentState = .error
            }

        case .waitingBefore:

            if updatedBusState != .idle_HH && updatedBusState != .transmitting_HH {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterStart {
                    currentState = .pullingSDA
                    xRef = nil
                }
            }

        case .pullingSDA:

            if updatedBusState == .started_LH {
                currentState = .waitingAfter
            } else if updatedBusState != .idle_HH && updatedBusState != .transmitting_HH {
                currentState = .error
            }

        case .waitingAfter:

            if updatedBusState != .started_LH {
                currentState = .error
            } else {
                if xRef == nil {
                    xRef = x
                }
                if x - xRef! >= xWaitAfterStart {
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
