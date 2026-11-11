
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CMasterController: I2CController {
    
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil
    
    private let xStepDefaultSetup: CGFloat = 30
    private let xStepBitClockHigh: CGFloat = 100
    
    
    func schedule(_ transmission: I2CTransmission, at x: CGFloat) {
        
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }
    
    
    override func compute(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        if self.activeTransmission == nil {
            activateNextTransmission(x: x)
        }
        
        if let transmission = activeTransmission {
            
            pullSDALow()
            endCurrentTransmission()
        }
    }
    
    
    private func endCurrentTransmission() {
        
        activeTransmission = nil
    }
    
    
    private func activateNextTransmission(x: CGFloat) {
        
        if let entry = self.scheduledTransmissions.first, entry.x <= x {
            
            _ = self.scheduledTransmissions.dropFirst()
            self.activeTransmission = entry.transmission
        }
    }
}
