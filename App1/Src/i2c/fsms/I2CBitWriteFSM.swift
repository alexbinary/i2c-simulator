
import SwiftUI



enum I2CBitWriteFSMState {
    
    case pullingSCLLow
    case assertingSDA
    case waitingLowBefore
    case clockingHigh
    case waitingHigh
    case clockingLow
    case waitingLowAfter
    case done
}


class I2CBitWriteFSM {
    
    
    var currentState: I2CBitWriteFSMState = .pullingSCLLow
    

    func reset() {

        currentState = .pullingSCLLow
    }
    
    func SCLReady() {
        
        if currentState == .pullingSCLLow {
            currentState = .assertingSDA
        }
    }

    func SDAAsserted() {
        
        if currentState == .assertingSDA {
            currentState = .waitingLowBefore
        }
    }

    func waitedLowBefore() {
        
        if currentState == .waitingLowBefore {
            currentState = .clockingHigh
        }
    }
    
    func gotClockHigh() {
        
        if currentState == .clockingHigh {
            currentState = .waitingHigh
        }
    }
    
    func waitedHigh() {
        
        if currentState == .waitingHigh {
            currentState = .clockingLow
        }
    }
    
    func gotClockLow() {
        
        if currentState == .clockingLow {
            currentState = .waitingLowAfter
        }
    }
    
    func waitedLowAfter() {
        
        if currentState == .waitingLowAfter {
            currentState = .done
        }
    }
}

