
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    
    let busLineSCL = I2CBusLine()
    let busLineSDA = I2CBusLine()
    
    var currentX: CGFloat = 0
    
    let lineSCL = RenderSceneLine()
    let lineSDA = RenderSceneLine()
    
    let pullerId = UUID()
    
    let xStepDefaultSetup: CGFloat = 30
    let xStepBitClockHigh: CGFloat = 100
    
    
    init() {
        
        self.run()
    }
    
    
    func advanceX(by step: CGFloat) {
        
        if (step < 0) { fatalError("X must always go forward") }
        
        self.currentX += step
        
        updateLinesX()
    }
    
    
    func advanceX(to x: CGFloat) {
        
        if (x < self.currentX) { fatalError("X must always go forward") }
        
        self.currentX = x
        
        updateLinesX()
    }
    
    
    func updateLinesX() {
     
        busLineSCL.advanceX(to: currentX)
        busLineSDA.advanceX(to: currentX)
    }
    
    
    func run() {
        
        lineSCL.initialLevel = busLineSCL.currentLevel
        lineSDA.initialLevel = busLineSDA.currentLevel
        
        advanceX(by: 100)
        
        i2c_start()

        i2c_sendBit(.zero)
        i2c_sendBit(.one)
        i2c_ack()

        i2c_start()

        i2c_sendBit(.zero)
        i2c_sendBit(.one)
        i2c_nack()

        i2c_stop()
        
        
        lineSCL.transitions = busLineSCL.transitions
        lineSDA.transitions = busLineSDA.transitions
    }
    
    
    func i2c_pullSDALow() {

        busLineSDA.addPuller(self.pullerId)
    }

    func i2c_pullSCLLow() {

        busLineSCL.addPuller(self.pullerId)
    }

    func i2c_releaseSDA() {

        busLineSDA.removePuller(self.pullerId)
    }

    func i2c_releaseSCL() {
        
        busLineSCL.removePuller(self.pullerId)
    }

    func i2c_SDAIsLow() -> Bool {

        return busLineSDA.isLow
    }

    func i2c_SDAIsHigh() -> Bool {

        return busLineSDA.isHigh
    }

    func i2c_SCLIsLow() -> Bool {

        return busLineSCL.isLow
    }

    func i2c_SCLIsHigh() -> Bool {

        return busLineSCL.isHigh
    }
    
    
    func i2c_start() {

        if i2c_SDAIsLow() {

            i2c_pullSCLLow()
            advanceX(by: xStepDefaultSetup)

            i2c_releaseSDA()
            advanceX(by: xStepDefaultSetup)
        }

        i2c_releaseSCL()
        advanceX(by: xStepDefaultSetup)

        i2c_pullSDALow()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_stop() {

        i2c_pullSCLLow()
        advanceX(by: xStepDefaultSetup)

        i2c_pullSDALow()
        advanceX(by: xStepDefaultSetup)

        i2c_releaseSCL()
        advanceX(by: xStepDefaultSetup)

        i2c_releaseSDA()
        advanceX(by: xStepDefaultSetup)
    }


    func i2c_sendBit(_ bit: Bit) {

        if i2c_SCLIsHigh() {

            i2c_pullSCLLow()
            advanceX(by: xStepDefaultSetup)
        }

        if bit == .zero {
            i2c_pullSDALow()
        } else {
            i2c_releaseSDA()
        }
        advanceX(by: xStepDefaultSetup)

        i2c_releaseSCL()
        advanceX(by: xStepBitClockHigh)

        i2c_pullSCLLow()
        advanceX(by: xStepDefaultSetup)
    }


    func i2c_ack() {

        i2c_sendBit(.zero)
    }


    func i2c_nack() {

        i2c_sendBit(.one)
    }
}
