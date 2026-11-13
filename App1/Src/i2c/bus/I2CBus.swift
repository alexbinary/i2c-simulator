
import SwiftUI



class I2CBus {
    
    
    let lineSCL = I2CBusLine(.SCL)
    let lineSDA = I2CBusLine(.SDA)
    
    private var controllers: [I2CController] = []
    
    private var currentX: CGFloat = 0
    private var minimumComputeX: CGFloat = 1


    func line(_ identity: I2CBusLineEnum) -> I2CBusLine {

        switch identity {
        case .SCL: return lineSCL
        case .SDA: return lineSDA
        }
    }
    
    
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
        
        for line in [lineSCL, lineSDA] {
            line.removeAllPullers()
            line.updateLevel()
        }

        advanceX(to: startX)

        for controller in controllers {
            controller.initCompute(x: currentX, levelSCL: lineSCL.currentLevel, levelSDA: lineSDA.currentLevel)
        }

        var changedLines: [I2CBusLineEnum] = []
        
        while currentX < endX {

            let changedLineCalls: [I2CBusLineEnum?] = changedLines.count > 0 ? changedLines.shuffled() : [nil]
            for changedLine in changedLineCalls {

                print("")
                if let changedLine = changedLine {    
                    print("-- TRANSITION: \(changedLine) \(line(changedLine).currentLevel) --")
                } else {
                    print("-- CLOCK TICK: \(currentX) --")
                }

                for controller in controllers.shuffled() {
                    if let action = controller.updateCompute(x: currentX, changedLine: changedLine) {
                        let line = line(action.target)
                        switch action.type {
                        case .pull: line.addPuller(controller)
                        case .release: line.removePuller(controller)
                        }
                    }
                }
            }

            advanceX(by: minimumComputeX)
            
            changedLines.removeAll()
            for line in [lineSCL, lineSDA] {
                let lineHasChanged = line.updateLevel()
                if lineHasChanged {
                    line.registerTransition(at: currentX)
                    changedLines.append(line.identity)
                }
            }
        }
    }
}
