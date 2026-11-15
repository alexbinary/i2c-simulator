
import SwiftUI



enum I2CStartFSMState {
    
    case waitingIdle
    case waitingSDApull

    static var initialState: I2CStartFSMState { .waitingIdle }
}


class I2CStartFSM {
    
    private(set) var currentState: I2CStartFSMState = .initialState
    
    private let xWaitBeforeStart: CGFloat = 30
    private let xWaitAfterStart: CGFloat = 30
    private var xRef: CGFloat?


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

            if nextState != currentState {
                currentState = nextState
                continue
            } else {
                break
            }
        }
    }
}
