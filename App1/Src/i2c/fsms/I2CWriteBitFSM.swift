
import SwiftUI



enum I2CWriteBitFSMState {
    
    case preparingLines
    case clockingHigh
    case waitingHigh
    case clockingLow
    case waitingLow
    case done
}


class I2CWriteBitFSM {
    
    
    var currentState: I2CWriteBitFSMState = .preparingLines
    
    
    func linesReady() {
        
        if currentState == .preparingLines {
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
            currentState = .waitingLow
        }
    }
    
    func waitedLow() {
        
        if currentState == .waitingLow {
            currentState = .done
        }
    }
}

