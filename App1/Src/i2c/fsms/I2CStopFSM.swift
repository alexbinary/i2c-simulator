
import SwiftUI



enum I2CStopFSMState {
    
    case waitingConditions
    case releasingSDA

    static var initialState: I2CStopFSMState { .waitingConditions }
}


class I2CStopFSM {
    
    
    private(set) var currentState: I2CStopFSMState = .initialState


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM, onSuccess: () -> (), onError: () -> ()) {

        while true {

            var nextState = currentState

            func success() {
                onSuccess()
                nextState = .initialState
            }
            
            func error() {
                onError()
                nextState = .initialState
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

            if nextState != currentState {
                currentState = nextState
                continue
            } else {
                break
            }
        }
    }
}
