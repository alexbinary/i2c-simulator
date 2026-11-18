
import SwiftUI



enum I2CStopFSMState {
    
    case waitingConditions
    case releasingSDA

    static var initialState: I2CStopFSMState { .waitingConditions }
}


class I2CStopFSM {
    
    
    private(set) var currentState: I2CStopFSMState = .initialState
    
    
    init() {
        reset()
    }
    
    
    func reset() {
        currentState = .initialState
    }


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM, onSuccess: () -> (), onError: () -> ()) {

        while true {

            var nextState = currentState
            var exit = false

            func success() {
                reset()
                onSuccess()
                exit = true
            }
            
            func error() {
                reset()
                onError()
                exit = true
            }

            switch currentState {
            case .waitingConditions:

                if updatedBusFSM.currentState == .started_LH || updatedBusFSM.currentState == .transmitting_LH {
                    nextState = .releasingSDA
                }

            case .releasingSDA:

                if updatedBusFSM.currentState == .idle_HH {
                    success()
                } else if updatedBusFSM.currentState != .started_LH && updatedBusFSM.currentState != .transmitting_LH {
                    error()
                }
            }

            if nextState == currentState || exit {
                break
            } else {
                currentState = nextState
                continue
            }
        }
    }
}
