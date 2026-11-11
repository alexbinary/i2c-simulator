
import SwiftUI



enum I2CStartStopFSMState {
    
    case preparingLines
    case waitingBefore
    case assertingLines
    case waitingAfter
    case done
}


class I2CStartStopFSM {
    
    
    var currentState: I2CStartStopFSMState = .preparingLines
    
    
    func reset() {
        
        currentState = .preparingLines
    }
    
    func linesReady() {
        
        if currentState == .preparingLines {
            currentState = .waitingBefore
        }
    }

    func waitedBefore() {
        
        if currentState == .waitingBefore {
            currentState = .assertingLines
        }
    }
    
    func linesAsserted() {
        
        if currentState == .assertingLines {
            currentState = .waitingAfter
        }
    }

    func waitedAfter() {
        
        if currentState == .waitingAfter {
            currentState = .done
        }
    }
}
