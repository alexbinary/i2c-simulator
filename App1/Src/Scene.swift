
import SwiftUI



class RenderScene {
    
    let bus = I2CBus()


    init() {
        
        self.run()
    }
    
    
    func run() {

        bus.reset()
        
        let devices: [I2CBusConnectable] = [
            EquipmentTestMaster1(),
//            EquipmentRegisterBank(i2cAddress: 0x2a),
            EquipmentRegisterBank(i2cAddress: 0x61),
//            EquipmentBusMonitor(),
            PerturbatorEquipment(),
        ]
        for device in devices {
            device.connect(to: bus)
        }
        
        let startX: CGFloat = 0
        let endX: CGFloat = 12000
        let simStepX: CGFloat = 1
        
        var currentX = startX
        
        bus.captureLineLevels(at: currentX)
        
        for device in devices {
            device.reset(x: currentX)
        }
        
        while currentX < endX {
        
            for device in devices {
                device.update(x: currentX)
            }
            currentX += simStepX
            bus.captureLineLevels(at: currentX)
        }
    }
}
