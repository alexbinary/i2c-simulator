
import SwiftUI



enum I2CStartFSMState {
    
    case waitingIdle
    case waitingSDApull

    static var initialState: I2CStartFSMState { .waitingIdle }
}


class I2CStartFSM {
    
    private(set) var currentState: I2CStartFSMState = .initialState
    
    
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
            case .waitingIdle:

                if updatedBusFSM.currentState == .idle_HH {
                    nextState = .waitingSDApull
                }

            case .waitingSDApull:

                if updatedBusFSM.currentState == .started_LH {
                    success()
                } else if updatedBusFSM.currentState != .idle_HH {
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
