
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


    func update(afterLineChange changedLine: I2CBusLineEnum, updatedBusState: I2CBusFSMState, onSuccess: () -> (), onError: () -> ()) {

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

                if updatedBusState == .started_LH || updatedBusState == .transmitting_LH {
                    nextState = .releasingSDA
                }

            case .releasingSDA:

                if updatedBusState == .idle_HH {
                    success()
                } else if updatedBusState != .started_LH && updatedBusState != .transmitting_LH {
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
