
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    
    let i2cBus = I2CBus()
    let i2cMaster = I2CController()
    
    //
    
    let lineSCL = RenderSceneLine()
    let lineSDA = RenderSceneLine()
    
    
    init() {
        
        self.run()
    }
    
    
    func run() {
        
        lineSCL.initialLevel = i2cBus.lineSCL.currentLevel
        lineSDA.initialLevel = i2cBus.lineSDA.currentLevel
        
        //
        
        i2cBus.connect(i2cMaster)
        
        i2cBus.simulate(from: 0, to: 1000, by: 1)
        
        //
        
        lineSCL.transitions = i2cBus.lineSCL.transitions
        lineSDA.transitions = i2cBus.lineSDA.transitions
    }
}
