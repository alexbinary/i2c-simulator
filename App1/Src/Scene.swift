
import SwiftUI



class RenderScene {
    
    let bus = I2CBus()


    init() {
        
        self.run()
    }
    
    
    func run() {

        bus.reset()
        
        let equipments = [
            EquipmentTestMaster1(),
            EquipmentTestSlave1(i2cAddress: 0x2a),
            EquipmentTestSlave2(i2cAddress: 0x61),
        ]
        for equipment in equipments {
            equipment.i2cController.connect(to: bus)
        }
        
        let startX: CGFloat = 0
        let endX: CGFloat = 9000
        let simStepX: CGFloat = 1
        
        var currentX = startX
        
        bus.captureLineLevels(at: currentX)
        
        for equipment in equipments {
            equipment.reset(x: currentX)
        }
        
        while currentX < endX {
        
            for equipment in equipments {
                equipment.update(x: currentX)
            }
            currentX += simStepX
            bus.captureLineLevels(at: currentX)
        }
    }
}
