
import SwiftUI



enum I2CWriteBitFSMState {
    
    case preparingLines
    case waitingLowBefore
    case clockingHigh
    case waitingHigh
    case clockingLow
    case waitingLowAfter
    case done
}


class I2CWriteBitFSM {
    
    
    var currentState: I2CWriteBitFSMState = .preparingLines
    

    func reset() {

        currentState = .preparingLines
    }
    
    func linesReady() {
        
        if currentState == .preparingLines {
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

