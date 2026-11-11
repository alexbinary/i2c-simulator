
import SwiftUI



class I2CBus {
    
    
    let lineSCL = I2CBusLine()
    let lineSDA = I2CBusLine()
    
    private var controllers: [I2CController] = []
    
    private var currentX: CGFloat = 0
    private var minimumComputeX: CGFloat = 1
    private var defaultIdleStepX: CGFloat = 10
    
    
    func connect(_ controller: I2CController) {
        
        controllers.append(controller)
    }
    
    
    func advanceX(by step: CGFloat) {
        
        if (step < 0) { fatalError("X must always go forward") }
        
        self.currentX += step
    }
    
    
    func advanceX(to x: CGFloat) {
        
        if (x < self.currentX) { fatalError("X must always go forward") }
        
        self.currentX = x
    }
    
    
    func simulate(from startX: CGFloat, to endX: CGFloat) {
        
        advanceX(to: startX)
        
        while true {
            
            let linesChanged = controllersCompute()
            
            let delay = linesChanged ? 0 : defaultIdleStepX
            let nextX = currentX + delay
            
            if nextX > endX { break }
            currentX = nextX
        }
    }
    
    
    func controllersCompute() -> Bool {
        
        controllers.forEach { controller in
            
            controller.compute(levelSCL: lineSCL.currentLevel, levelSDA: lineSDA.currentLevel, x: currentX)
        }
        
        advanceX(by: minimumComputeX)
        
        controllers.forEach { controller in
            
            if controller.pullingSCLLow {
                lineSCL.addPuller(controller)
            } else {
                lineSCL.removePuller(controller)
            }
            if controller.pullingSDALow {
                lineSDA.addPuller(controller)
            } else {
                lineSDA.removePuller(controller)
            }
        }
        
        var linesChanged = false
        
        for line in [lineSCL, lineSDA] {
            
            let lineChanged = line.updateLevel()
            if lineChanged {
                
                line.registerTransition(at: currentX)
                linesChanged = true
            }
        }
        
        return linesChanged
    }
}
