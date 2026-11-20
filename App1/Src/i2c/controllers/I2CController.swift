
import SwiftUI



class I2CController {
    
    
    let id = UUID()
    var bus: I2CBus!

    var pullingSDA = false
    var pullingSCL = false
    
    func pulling(_ line: I2CBusLine.Identity) -> Bool {
        switch line {
        case .SCL: return pullingSCL
        case .SDA: return pullingSDA
        }
    }
    
    
    func connect(to bus: I2CBus) {
        
        self.bus = bus
    }
    
    
    func detectedStartCondition(analysingTransitionFrom lineLevelsBefore: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel), to lineLevelsAfter: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)) -> Bool {
        
        return lineLevelsBefore == (SCL: .high, SDA: .high) && lineLevelsAfter == (SCL: .high, SDA: .low)
    }
    
    
    func detectedStopCondition(analysingTransitionFrom lineLevelsBefore: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel), to lineLevelsAfter: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)) -> Bool {
        
        return lineLevelsBefore == (SCL: .high, SDA: .low) && lineLevelsAfter == (SCL: .high, SDA: .high)
    }
    
    
    func initState(x: CGFloat) {

    }
    
    
    func updateBusControl(x: CGFloat) {
        
    }
}
