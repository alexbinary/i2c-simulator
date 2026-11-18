
import SwiftUI



enum I2CStopFSMState {
    
    case waitingPreCondition
    case waitingSDARelease
}


class I2CStopFSM {
    
    
    var currentState: I2CStopFSMState = .waitingPreCondition
    var currentLineLevels: I2CBusLineLevels = .init(SCL: .high, SDA: .high)
    
    
    func reset(lineLevels: I2CBusLineLevels) {
        
        currentLineLevels = lineLevels
        currentState = .waitingPreCondition
    }
    
    
    func reset() {
        
        reset(lineLevels: currentLineLevels)
    }


    func update(afterLineChange changedLine: I2CBusLineEnum, onSuccess: () -> (), onError: () -> ()) {
        
        currentLineLevels = currentLineLevels.updated(afterLineChange: changedLine)
        
        switch currentState {
        case .waitingPreCondition:
            
            if currentLineLevels.match(SCL: .high, SDA: .low) {
                currentState = .waitingSDARelease
            }
            
        case .waitingSDARelease:
            
            if currentLineLevels.match(SCL: .high, SDA: .high) {
                reset()
                onSuccess()
            } else {
                reset()
                onError()
            }
        }
    }
}
