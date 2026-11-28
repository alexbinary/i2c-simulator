
import SwiftUI



class RenderScene {
    
    let bus = I2CBus()
    
    var markers: [SimulationMarker] = []


    init() {
        
        self.run()
    }
    
    
    func run() {

        let entities: [SimulationEntity] = [
            EquipmentTestMaster1(),
//            EquipmentRegisterBank(i2cAddress: 0x2a),
//            EquipmentRegisterBank(i2cAddress: 0x61),
//            EquipmentBusMonitor(),
            PerturbatorEquipment(name: "PER"),
        ]
        
        let startX: CGFloat = 0
        let endX: CGFloat = 2000
        let simStepX: CGFloat = 1
        
        var currentX = startX
        
        bus.reset()
        
        for entity in entities {
            entity.reset(x: currentX)
        }
        
        bus.captureLineLevels(at: currentX)
        
        let devices: [I2CBusConnectable] = entities.compactMap { $0 as? I2CBusConnectable }
        for device in devices {
            device.connect(to: bus)
        }
        
        while currentX < endX {
        
            for entity in entities {
                entity.update(x: currentX)
            }
            currentX += simStepX
            bus.captureLineLevels(at: currentX)
        }
        
        markers = []
        for entity in entities {
            markers += entity.markers
        }
    }
}
