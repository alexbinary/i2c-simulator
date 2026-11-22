
import SwiftUI



class EquipmentTestMaster1: Equipment {
    
    var i2cMasterController: I2CMasterController { self.i2cController as! I2CMasterController }
    
    var transmissions: [I2CTransmission] = [
        
        I2CTransmission(writeTo: 0x2b, bytes: [0x01, 0x02]),
        
        I2CTransmission(writeTo: 0x2a, bytes: [0x01, 0x02]),
        I2CTransmission(readFrom: 0x2a, bytes: 2),
        
        I2CTransmission(writeTo: 0x61, bytes: [0x03, 0x04]),
        I2CTransmission(readFrom: 0x61, bytes: 5),
    ]
    
    override init() {
        super.init()
        i2cController = I2CMasterController(onTransmissionEnded: onTransmissionEnded)
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
        print("-- EquipmentTestMaster1 RESET: \(x) --")
        
        activateNextTransmission()
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
        print("-- EquipmentTestMaster1 UPDATE: \(x) --")
    }
    
    
    func activateNextTransmission() {
        
        guard !transmissions.isEmpty else { return }
        let transmission = transmissions.removeFirst()
        i2cMasterController.scheduleTransmission(at: 0, transmission)
    }
    
    
    func onTransmissionEnded(result: I2CMasterController.TransmissionResult) {
        
        print("-- EquipmentTestMaster1 TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.payload.address)+\(result.payload.mode), transmittedBytes: \(result.payload.transmittedBytes)")
        
        self.activateNextTransmission()
    }
}
