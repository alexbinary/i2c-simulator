
import SwiftUI



enum I2CBitReadFSMState {
    
    case waitingLowBefore
    case clockingHigh
    case waitingHigh
    case reading
    case clockingLow
    case waitingLowAfter
    case done
}


class I2CBitReadFSM {
    
    
    var currentState: I2CBitReadFSMState = .waitingLowBefore
    

    func reset() {

        currentState = .waitingLowBefore
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
            currentState = .reading
        }
    }

    func readBit() {

        if currentState == .reading {
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

