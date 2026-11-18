
import SwiftUI



enum I2CStartFSMState {
    
    case waitingPreCondition
    case waitingSDADrop
}


class I2CStartFSM {
    
    var currentState: I2CStartFSMState = .waitingPreCondition
    var currentLineLevels: I2CBusLineLevels = .init(SCL: .high, SDA: .high)
    
    
    func reset(lineLevels: I2CBusLineLevels) {
        
        currentState = .waitingPreCondition
        currentLineLevels = lineLevels
    }
    
    
    func reset() {
        
        reset(lineLevels: currentLineLevels)
    }


    func update(afterLineChange changedLine: I2CBusLineEnum, onStart startDetected: () -> ()) {
        
        currentLineLevels = currentLineLevels.updated(afterLineChange: changedLine)
                         
        switch currentState {
        case .waitingPreCondition:
            
            if currentLineLevels.match(SCL: .high, SDA: .high) {
                currentState = .waitingSDADrop
            }
            
        case .waitingSDADrop:
            
            if currentLineLevels.match(SCL: .high, SDA: .low) {
                reset()
                startDetected()
            } else {
                currentState = .waitingPreCondition
            }
        }
    }
}
