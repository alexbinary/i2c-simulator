
import SwiftUI



class I2CController {
    
    
    let id = UUID()
    
    var busFSM = I2CBusFSM()
    
    private var lastLevelSCL: LineLevel?
    private var lastLevelSDA: LineLevel?
    
    private(set) var pullingSDALow: Bool = false
    private(set) var pullingSCLLow: Bool = false
    
    private var lastX: CGFloat = 0
    

    init(
        
    ) {
        
    }
    
    
    func compute(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        busFSM.update(
            levelSCL: levelSCL, levelSDA: levelSDA,
            SCLchanged: levelSCL != lastLevelSCL, SDAchanged: levelSDA != lastLevelSDA
        )

        _compute(levelSCL: levelSCL, levelSDA: levelSDA, x: x)

        lastLevelSCL = levelSCL
        lastLevelSDA = levelSDA
    }


    func _compute(levelSCL: LineLevel, levelSDA: LineLevel, x: CGFloat) {
        
        
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
