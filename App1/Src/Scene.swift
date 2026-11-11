
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    
    var i2cBus = I2CBus()
    
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
     
        i2cBus.advanceX(to: currentX)
    }
    
    
    func run() {
        
        lineSCL.initialLevel = i2cBus.lineSCL.currentLevel
        lineSDA.initialLevel = i2cBus.lineSDA.currentLevel
        
        //
        
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
        
        //
        
        lineSCL.transitions = i2cBus.lineSCL.transitions
        lineSDA.transitions = i2cBus.lineSDA.transitions
    }
    
    
    func i2c_pullSDALow() {

        i2cBus.pullSDALow(self.pullerId)
    }

    func i2c_pullSCLLow() {

        i2cBus.pullSCLLow(self.pullerId)
    }

    func i2c_releaseSDA() {

        i2cBus.releaseSDA(self.pullerId)
    }

    func i2c_releaseSCL() {
        
        i2cBus.releaseSCL(self.pullerId)
    }

    func i2c_SDAIsLow() -> Bool {

        return i2cBus.SDAIsLow()
    }

    func i2c_SDAIsHigh() -> Bool {

        return i2cBus.SDAIsHigh()
    }

    func i2c_SCLIsLow() -> Bool {

        return i2cBus.SCLIsLow()
    }

    func i2c_SCLIsHigh() -> Bool {

        return i2cBus.SCLIsHigh()
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
