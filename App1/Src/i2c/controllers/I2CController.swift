
import SwiftUI



class I2CController {
    
    
    let id = UUID()
    
    private(set) var pullingSDALow: Bool = false
    private(set) var pullingSCLLow: Bool = false
    
    private var lastX: CGFloat = 0
    
    var busFSM = I2CBusFSM()

    
    init(
        
    ) {
        
    }
    
    
    func compute(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        busFSM.update(levelSCL: levelSCL, levelSDA: levelSDA)
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
}
