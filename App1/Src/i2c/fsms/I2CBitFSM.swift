
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
        
        currentState = .setup
        currentLineLevels = lineLevels
        readBit = nil
    }
    
    
    func reset() {
        
        reset(lineLevels: currentLineLevels)
    }
    

    func update(afterLineChange changedLine: I2CBusLineEnum, onBitClocked clockedBitDetected: (Bit) -> ()) {
        
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
                clockedBitDetected(bit)
            }
        }
    }
}
