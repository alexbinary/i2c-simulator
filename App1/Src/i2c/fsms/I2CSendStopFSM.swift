
import SwiftUI



enum I2CStopFSMState {
    
    case ready
    case pullingSDA
    case releasingSCL
    case waitingBefore
    case releasingSDA
    case waitingAfter
    case done
    case error
}


class I2CSendStopFSM {
    
    
    private(set) var currentState: I2CStopFSMState = .ready
    
    private let xWaitBeforeStop: CGFloat = 30
    private let xWaitAfterStop: CGFloat = 30
    private var xRef: CGFloat?


    func reset() {
        
        currentState = .ready
    }


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM) {

        while true {

            var nextState = currentState

            switch currentState {
            case .ready:

                if updatedBusFSM.currentState == .started_LH {
                    nextState = .waitingBefore
                } else if updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .pullingSDA
                } else if updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .releasingSCL
                } else {
                    nextState = .error
                }
            
            case .pullingSDA:

                if updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .releasingSCL
                } else if updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                }

            case .releasingSCL:

                if updatedBusFSM.currentState == .transmitting_LH {
                    nextState = .waitingBefore
                } else if updatedBusFSM.currentState != .transmitting_LL {
                    nextState = .error
                }

            case .waitingBefore:

                if updatedBusFSM.currentState != .started_LH && updatedBusFSM.currentState != .transmitting_LH {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitBeforeStop {
                        nextState = .releasingSDA
                        xRef = nil
                    }
                }

            case .releasingSDA:

                if updatedBusFSM.currentState == .idle_HH {
                    nextState = .waitingAfter
                } else if updatedBusFSM.currentState != .started_LH && updatedBusFSM.currentState != .transmitting_LH {
                    nextState = .error
                }

            case .waitingAfter:

                if updatedBusFSM.currentState != .idle_HH {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitAfterStop {
                        nextState = .done
                        xRef = nil
                    }
                }
            
            case .done:
                break

            case .error:
                break
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
