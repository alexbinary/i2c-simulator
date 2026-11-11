
import SwiftUI



class I2CBus {
    
    
    let lineSCL = I2CBusLine()
    let lineSDA = I2CBusLine()
    
    var controllers: [I2CController] = []
    
    var currentX: CGFloat = 0
    
    
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
    
    
    func simulate(from startX: CGFloat, to endX: CGFloat, by stepX: CGFloat) {
        
        advanceX(to: startX)
        
        while (currentX + stepX) < endX {
            
            simulateStep()
            
            advanceX(by: stepX)
        }
        
        advanceX(to:endX)
        
        simulateStep()
    }
    
    
    func simulateStep() {
        
        controllers.forEach { controller in
            
            controller.simulateStep(levelSCL: lineSCL.currentLevel, levelSDA: lineSDA.currentLevel, x: currentX)
            
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
        
        for line in [lineSCL, lineSDA] {
            
            let changed = line.updateLevel()
            if changed {
                line.registerTransition(at: currentX)
            }
        }
    }
}
