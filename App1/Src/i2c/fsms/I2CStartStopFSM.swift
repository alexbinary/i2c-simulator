
import SwiftUI



enum I2CStartStopFSMState {
    
    case ready
    case waitingIdle
    case pullingSDA
    case waitingAfter
    case done
    case error
}


class I2CStartStopFSM {
    
    
    private(set) var currentState: I2CStartStopFSMState = .ready
    
    private let xWaitAfterStart: CGFloat = 30
    private var xRef: CGFloat?


    func reset() {
        
        currentState = .ready
    }


    func activate() {

        currentState = .waitingIdle
    }


    func update(x: CGFloat, updatedBusState: I2CBusFSMState) {

        switch currentState {

        case .ready:
            break

        case .waitingIdle:

            if updatedBusState == .idle_HH {
                currentState = .pullingSDA
            }

        case .pullingSDA:

            if updatedBusState == .started_LH {
                currentState = .waitingAfter
            } else if updatedBusState != .idle_HH {
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
