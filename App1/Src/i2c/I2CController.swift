
import SwiftUI



struct ScheduledTransmission {
    
    let transmission: I2CTransmission
    let x: CGFloat
}



class I2CController {
    
    
    let id = UUID()
    
    private(set) var pullingSDALow: Bool = false
    private(set) var pullingSCLLow: Bool = false
    
    private var scheduledTransmissions: [ScheduledTransmission] = []
    private var activeTransmission: I2CTransmission? = nil
    
    private var lastX: CGFloat = 0
    
    private let xStepDefaultSetup: CGFloat = 30
    private let xStepBitClockHigh: CGFloat = 100
    
    
    init(
        
    ) {
        
    }
    
    
    func schedule(_ transmission: I2CTransmission, at x: CGFloat) {
     
        self.scheduledTransmissions.append(ScheduledTransmission(transmission: transmission, x: x))
    }
    
    
    func simulateStep(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        updatePulls(levelSCL: levelSCL, levelSDA: levelSDA, x: x)
        
        lastX = x
    }
    
    
    func updatePulls(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
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
    
    
    private func pullSDALow() {
        
        pullingSDALow = true
    }
    
    private func releaseSDA() {
        
        pullingSDALow = false
    }
    
    private func pullSCLLow() {
        
        pullingSCLLow = true
    }
    
    private func releaseSCL() {
        
        pullingSCLLow = false
    }
}
