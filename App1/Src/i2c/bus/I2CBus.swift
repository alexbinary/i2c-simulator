
import SwiftUI



class I2CBus {
    
    
    let lineSCL = I2CBusLine(.SCL)
    let lineSDA = I2CBusLine(.SDA)
    func line(_ identity: I2CBusLine.Identity) -> I2CBusLine {
        switch identity {
        case .SCL: return lineSCL
        case .SDA: return lineSDA
        }
    }
    var currentLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) { (SCL: lineSCL.currentLevel, SDA: lineSDA.currentLevel) }
    
    var controllers: [I2CController] = []
    var simStepX: CGFloat = 1


    func reset() {

        lineSCL.reset()
        lineSDA.reset()
    }


    func connect(_ controller: I2CController) {
        
        controllers.append(controller)
        controller.connect(to: self)
    }
    
    
    func connect(_ equipment: Equipment) {
        
        connect(equipment.i2cController)
    }
    
    
    func simulate(from startX: CGFloat, to endX: CGFloat) {

        var currentX = startX
        
        for line in [lineSCL, lineSDA] {
            line.captureLevel(at: currentX)
        }
        
        for controller in controllers {
            controller.reset(x: currentX)
        }

        while currentX < endX {
            
            print("-- CLOCK TICK: \(currentX) --")
            
            for controller in controllers {
                controller.update(x: currentX)
            }
            
            currentX += simStepX
            
            for line in [lineSCL, lineSDA] {
                line.captureLevel(at: currentX)
            }
        }
    }
}
