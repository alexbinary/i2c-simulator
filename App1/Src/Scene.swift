
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    
    let lineSCL = RenderSceneLine()
    let lineSDA = RenderSceneLine()
    
    private let i2cBus = I2CBus()
    private let i2cMaster = I2CMasterController()
    private let i2cSlave1 = I2CSlaveController()
    private let i2cSlave2 = I2CSlaveController()


    init() {
        
        self.run()
    }
    
    
    func run() {
        
        lineSCL.initialLevel = i2cBus.lineSCL.currentLevel
        lineSDA.initialLevel = i2cBus.lineSDA.currentLevel
        
        //
        
        i2cBus.connect(i2cMaster)
        i2cBus.connect(i2cSlave1)
        i2cBus.connect(i2cSlave2)
        
        i2cMaster.schedule(I2CTransmission(addressRW: 0x2a<<1, bytes: [0x01, 0x02]), at: 100)
        
        i2cBus.simulate(from: 0, to: 10000)
        
        //
        
        lineSCL.transitions = i2cBus.lineSCL.transitions
        lineSDA.transitions = i2cBus.lineSDA.transitions
    }
}
