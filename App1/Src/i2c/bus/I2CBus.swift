
import SwiftUI



enum I2CBusEvent {
    
    case timeStep(step: CGFloat)
    case lineChange(line: I2CBusLineEnum)
}


class I2CBus {
    
    
    let lineSCL = I2CBusLine(.SCL)
    let lineSDA = I2CBusLine(.SDA)
    
    private var controllers: [I2CController] = []
    
    private var currentX: CGFloat = 0
    private var minimumComputeX: CGFloat = 1


    func reset() {

        lineSCL.reset()
        lineSDA.reset()
    }


    func line(_ identity: I2CBusLineEnum) -> I2CBusLine {

        switch identity {
        case .SCL: return lineSCL
        case .SDA: return lineSDA
        }
    }
    
    
    func connect(_ controller: I2CController) {
        
        controllers.append(controller)
        controller.connect(to: self)
    }
    
    
    func connect(_ equipment: Equipment) {
        
        connect(equipment.i2cController)
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

        for controller in controllers {
            controller.initState(x: currentX)
        }

        var changedLines: [I2CBusLineEnum] = []
        
        var previousX = currentX
        
        while currentX < endX {

            let xStep = currentX - previousX
            
            let events: [I2CBusEvent] =
            xStep > 0 ? [.timeStep(step: xStep)] : []
            + changedLines.map { .lineChange(line: $0) }
            
            for event in events {

                print("")
                switch event {
                case .lineChange(let changedLine):
                    print("-- TRANSITION: \(changedLine) \(line(changedLine).currentLevel) --")
                case .timeStep(let x):
                    print("-- CLOCK TICK: \(x) --")
                }

                for controller in controllers {
                    controller.updateBusControl(after: event)
                    if controller.pullingSDA {
                        lineSDA.addPuller(controller)
                    } else {
                        lineSDA.removePuller(controller)
                    }
                    if controller.pullingSCL {
                        lineSCL.addPuller(controller)
                    } else {
                        lineSCL.removePuller(controller)
                    }
                }
            }
            
            previousX = currentX

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
