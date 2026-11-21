
import SwiftUI



class RenderScene {
    
    let bus = I2CBus()


    init() {
        
        self.run()
    }
    
    
    func run() {

        bus.reset()
        
        bus.connect(EquipmentTestMaster1())
        bus.connect(EquipmentTestSlave1())
//        bus.connect(EquipmentTestSlave2())
//        bus.connect(I2CPerturbatorController())
        
        bus.simulate(from: 0, to: 5000)
    }
}
