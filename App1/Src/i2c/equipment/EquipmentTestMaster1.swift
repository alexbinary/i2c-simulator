
import SwiftUI



class EquipmentTestMaster1: Equipment {
    
    let master: I2CMasterController
    
//    let transmissions: [I2CTransmission] = [
//        
//        I2CTransmission(writeTo: 0x2b, bytes: [0x01, 0x02]),
//        
//        I2CTransmission(writeTo: 0x2a, bytes: [0x01, 0x02]),
//        I2CTransmission(readFrom: 0x2a, bytes: 2),
//        
//        I2CTransmission(writeTo: 0x61, bytes: [0x03, 0x04]),
//        I2CTransmission(readFrom: 0x61, bytes: 5),
//    ]
    
    init() {
        self.master = I2CMasterController(
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
        )
        
        super.init(i2cController: master)
        
        master.scheduleTransmission(at: 10, I2CTransmission(writeTo: 0x2b, bytes: [0x01, 0x02]))
        
        master.scheduleTransmission(at: 650, I2CTransmission(writeTo: 0x2a, bytes: [0x01, 0x02]))
        master.scheduleTransmission(at: 1400, I2CTransmission(readFrom: 0x2a, bytes: 2))
        
        master.scheduleTransmission(at: 2000, I2CTransmission(writeTo: 0x61, bytes: [0x03, 0x04]))
        master.scheduleTransmission(at: 2400, I2CTransmission(readFrom: 0x61, bytes: 5))
    }
}
