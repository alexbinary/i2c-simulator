
import SwiftUI



enum I2CStartStopFSMState {
    
    case preparingLines
    case assertingLines
    case done
}


class I2CStartStopFSM {
    
    
    var currentState: I2CStartStopFSMState = .preparingLines
    
    
    func linesReady() {
        
        if currentState == .preparingLines {
            currentState = .assertingLines
        }
    }
    
    func linesAsserted() {
        
        if currentState == .assertingLines {
            currentState = .done
        }
    }
}
