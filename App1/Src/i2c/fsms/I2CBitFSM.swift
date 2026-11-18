
import SwiftUI



enum I2CBitFSMState {
    
    case setup
    case clocking
}


class I2CBitFSM {
    
    var currentState: I2CBitFSMState = .setup
    var currentLineLevels: I2CBusLineLevels = .init(SCL: .high, SDA: .high)
    var readBit: Bit!
    
    
    func reset(lineLevels: I2CBusLineLevels) {
        
        currentLineLevels = lineLevels
        currentState = .setup
        readBit = nil
    }
    
    
    func reset() {
        
        reset(lineLevels: currentLineLevels)
    }
    

    func update(afterLineChange changedLine: I2CBusLineEnum, onSuccess: (Bit) -> (), onError: () -> ()) {
        
        currentLineLevels = currentLineLevels.updated(afterLineChange: changedLine)
        
        switch currentState {
        case .setup:
            
            if currentLineLevels.SCL == .high {
                currentState = .clocking
            }
            
        case .clocking:
            
            if currentLineLevels.SCL == .high {
                readBit = currentLineLevels.SDA.bit
            } else {
                let bit = readBit!
                reset()
                onSuccess(bit)
            }
        }
    }
}
