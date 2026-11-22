
import SwiftUI



class EquipmentTestMaster1: Equipment {
    
    var i2cMasterController: I2CMasterController { self.i2cController as! I2CMasterController }
    
    init() {
        super.init(i2cController: I2CMasterController(
            onTransmissionEnded: { status in
                print("-- EquipmentTestMaster1 TRANSMISSION ENDED --")
                switch status {
                case .addressNack:
                    print("address nack")
                case .success(let transmittedBytes):
                    print("success, transmittedBytes: \(transmittedBytes)")
                case .dataNack(let transmittedBytes):
                    print("data nack, transmittedBytes: \(transmittedBytes)")
                case .aborted(let transmittedBytes):
                    print("aborted, transmittedBytes: \(transmittedBytes)")
                }
            }
        ))
        
        i2cMasterController.scheduleTransmission(at: 10, I2CTransmission(writeTo: 0x2b, bytes: [0x01, 0x02]))
        
        i2cMasterController.scheduleTransmission(at: 650, I2CTransmission(writeTo: 0x2a, bytes: [0x01, 0x02]))
        i2cMasterController.scheduleTransmission(at: 1400, I2CTransmission(readFrom: 0x2a, bytes: 2))
        
        i2cMasterController.scheduleTransmission(at: 2000, I2CTransmission(writeTo: 0x61, bytes: [0x03, 0x04]))
        i2cMasterController.scheduleTransmission(at: 2400, I2CTransmission(readFrom: 0x61, bytes: 5))
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
        print("-- EquipmentTestMaster1 RESET: \(x) --")
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
        print("-- EquipmentTestMaster1 UPDATE: \(x) --")
    }
}
