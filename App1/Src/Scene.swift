
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: LineLevel = .high
    var transitions: [CGFloat] = []
}



class RenderScene {
    
    let lineSCL = RenderSceneLine()
    let lineSDA = RenderSceneLine()


    init() {
        
        self.run()
    }
    
    
    func run() {

        let bus = I2CBus()
        
        lineSCL.initialLevel = bus.lineSCL.currentLevel
        lineSDA.initialLevel = bus.lineSDA.currentLevel
        
        //

        let master = I2CMasterController()
        let slave1 = I2CSlaveController()
        let slave2 = I2CSlaveController()
        let perturbator = I2CPerturbatorController()
        
        bus.connect(master)
        bus.connect(slave1)
        bus.connect(slave2)
        bus.connect(perturbator)
        
        master.scheduleTransmission(at: 100, I2CTransmission(addressRW: 0x2a<<1+1, bytes: [0x01, 0x02]))
        
        bus.simulate(from: 0, to: 2000)
        
        //
        
        lineSCL.transitions = bus.lineSCL.transitions
        lineSDA.transitions = bus.lineSDA.transitions
    }
}
