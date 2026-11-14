
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


class I2CSendStartFSM {
    
    
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


    func update(x: CGFloat, updatedBusFSM: I2CBusFSM) {

        while true {

            var nextState = currentState

            switch currentState {

            case .ready:
                break

            case .activated:

                if updatedBusFSM.currentState == .idle_HH {
                    nextState = .waitingBefore
                } else if updatedBusFSM.currentState == .idle_LL {
                    nextState = .releasingSDA
                } else if updatedBusFSM.currentState == .idle_LH {
                    nextState = .releasingSDA
                } else if updatedBusFSM.currentState == .idle_HL {
                    nextState = .releasingSCL
                } else if updatedBusFSM.currentState == .transmitting_HL {
                    nextState = .releasingSCL
                } else if updatedBusFSM.currentState == .transmitting_LL {
                    nextState = .releasingSDA
                } else {
                    nextState = .error
                }

            case .releasingSCL:

                if updatedBusFSM.currentState == .idle_HH || updatedBusFSM.currentState == .transmitting_HH {
                    nextState = .waitingBefore
                } else if updatedBusFSM.currentState != .idle_HL && updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .error
                }

            case .releasingSDA:

                if updatedBusFSM.currentState != .idle_HL {
                    nextState = .releasingSCL
                } else if updatedBusFSM.currentState != .idle_HH {
                    nextState = .waitingBefore
                } else if updatedBusFSM.currentState != .transmitting_HL {
                    nextState = .releasingSCL
                } else if updatedBusFSM.currentState != .idle_LL && updatedBusFSM.currentState != .idle_LH && updatedBusFSM.currentState != .transmitting_LL {
                    nextState = .error
                }

            case .waitingBefore:

                if updatedBusFSM.currentState != .idle_HH && updatedBusFSM.currentState != .transmitting_HH {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitAfterStart {
                        nextState = .pullingSDA
                        xRef = nil
                    }
                }

            case .pullingSDA:

                if updatedBusFSM.currentState == .started_LH {
                    nextState = .waitingAfter
                } else if updatedBusFSM.currentState != .idle_HH && updatedBusFSM.currentState != .transmitting_HH {
                    nextState = .error
                }

            case .waitingAfter:

                if updatedBusFSM.currentState != .started_LH {
                    nextState = .error
                } else {
                    if xRef == nil {
                        xRef = x
                    }
                    if x - xRef! >= xWaitAfterStart {
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
