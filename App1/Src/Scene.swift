
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

        //
        
        bus.reset()
        
        lineSCL.initialLevel = bus.lineSCL.currentLevel
        lineSDA.initialLevel = bus.lineSDA.currentLevel
        
        //
        
        let master = EquipmentTestMaster1()
        let slave1 = EquipmentTestSlave1()
        let slave2 = EquipmentTestSlave2()
        
        let equipments = [master, slave1, slave2]
        
        for equipment in equipments {
            bus.connect(equipment)
        }
        
        let perturbator = I2CPerturbatorController()
        bus.connect(perturbator)
        
        bus.simulate(from: 0, to: 5000)
        
        //
        
        lineSCL.transitions = bus.lineSCL.transitions
        lineSDA.transitions = bus.lineSDA.transitions
    }
}
