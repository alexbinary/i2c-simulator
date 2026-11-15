
import SwiftUI



enum I2CBitFSMState {
    
    case setup
    case clockHigh

    static var initialState: I2CBitFSMState { .setup }
}


class I2CBitFSM {
    
    private(set) var currentState: I2CBitFSMState = .initialState
    private(set) var readBit: Bit!
    

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
            case .setup:

                if updatedBusFSM.currentState == .transmitting_LH || updatedBusFSM.currentState == .transmitting_HH {
                    nextState = .clockHigh
                } else if updatedBusFSM.currentState != .started_LH && updatedBusFSM.currentState != .transmitting_HL && updatedBusFSM.currentState != .transmitting_LL {
                    error()
                }

            case .clockHigh:

                if updatedBusFSM.currentState == .transmitting_LL || updatedBusFSM.currentState == .transmitting_HL {
                    success()
                } else if updatedBusFSM.currentState != .transmitting_LH && updatedBusFSM.currentState != .transmitting_HH {
                    error()
                }

                readBit = updatedBusFSM.lineLevels.SDA == .high ? .one : .zero
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

