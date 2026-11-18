
import SwiftUI



class RenderSceneLine {
    
    var initialLevel: I2CLineLevel = .high
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

        //
        
        bus.reset()
        
        lineSCL.initialLevel = bus.lineSCL.currentLevel
        lineSDA.initialLevel = bus.lineSDA.currentLevel
        
        //
        
        let master = EquipmentTestMaster1()
        let slave1 = EquipmentTestSlave1()
        let slave2 = EquipmentTestSlave2()
        
        bus.connect(master)
//        bus.connect(slave1)
//        bus.connect(slave2)
        
        let perturbator = I2CPerturbatorController()
        bus.connect(perturbator)
        
        bus.simulate(from: 0, to: 5000)
        
        //
        
        lineSCL.transitions = bus.lineSCL.transitions
        lineSDA.transitions = bus.lineSDA.transitions
    }
}
