
import SwiftUI



class I2CController {
    
    
    let id = UUID()
    
    var pullingSDALow: Bool = false
    var pullingSCLLow: Bool = false
    
    let xStepDefaultSetup: CGFloat = 30
    let xStepBitClockHigh: CGFloat = 100
    
    
    init(
        
    ) {
        
    }
    
    
    func pullSDALow() {
        
        pullingSDALow = true
    }
    
    func releaseSDA() {
        
        pullingSDALow = false
    }
    
    func pullSCLLow() {
        
        pullingSCLLow = true
    }
    
    func releaseSCL() {
        
        pullingSCLLow = false
    }
    
    
    func simulateStep(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        pullingSDALow = true
    }
}
