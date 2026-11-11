
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    
    let i2cBus = I2CBus()
    let i2cMaster = I2CController()
    
    //
    
    var currentX: CGFloat = 0
    
    let lineSCL = RenderSceneLine()
    let lineSDA = RenderSceneLine()
    
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
        
        i2cMaster.connect(to: i2cBus)
        
        advanceX(by: 100)
        
        i2c_master_start()

        i2c_master_sendBit(.zero)
        i2c_master_sendBit(.one)
        i2c_master_ack()

        i2c_master_start()
        i2c_master_sendBit(.zero)
        i2c_master_sendBit(.one)
        i2c_master_nack()

        i2c_master_stop()
        
        //
        
        lineSCL.transitions = i2cBus.lineSCL.transitions
        lineSDA.transitions = i2cBus.lineSDA.transitions
    }
    
    
    func i2c_master_start() {
        
        if i2cBus.SDAIsLow() {
            
            i2cMaster.pullSCLLow()
            advanceX(by: xStepDefaultSetup)
            
            i2cMaster.releaseSDA()
            advanceX(by: xStepDefaultSetup)
        }
        
        i2cMaster.releaseSCL()
        advanceX(by: xStepDefaultSetup)
        
        i2cMaster.pullSDALow()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_master_stop() {
        
        i2cMaster.pullSCLLow()
        advanceX(by: xStepDefaultSetup)
        
        i2cMaster.pullSDALow()
        advanceX(by: xStepDefaultSetup)
        
        i2cMaster.releaseSCL()
        advanceX(by: xStepDefaultSetup)
        
        i2cMaster.releaseSDA()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_master_sendBit(_ bit: Bit) {
        
        if i2cBus.SCLIsHigh() {
            
            i2cMaster.pullSCLLow()
            advanceX(by: xStepDefaultSetup)
        }
        
        if bit == .zero {
            i2cMaster.pullSDALow()
        } else {
            i2cMaster.releaseSDA()
        }
        advanceX(by: xStepDefaultSetup)
        
        i2cMaster.releaseSCL()
        advanceX(by: xStepBitClockHigh)
        
        i2cMaster.pullSCLLow()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_master_ack() {
        
        i2c_master_sendBit(.zero)
    }
    
    
    func i2c_master_nack() {
        
        i2c_master_sendBit(.one)
    }
}
