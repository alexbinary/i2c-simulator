
import SwiftUI



class EquipmentTestMaster1: Equipment {
    
    let master = I2CMasterController()
    
    init() {
        super.init(i2cController: master)
        
        master.scheduleTransmission(at: 10, I2CTransmission(writeTo: 0x2b, bytes: [0x01, 0x02]))
        
        master.scheduleTransmission(at: 650, I2CTransmission(writeTo: 0x2a, bytes: [0x01, 0x02]))
        master.scheduleTransmission(at: 1400, I2CTransmission(readFrom: 0x2a, bytes: 2))
        
        master.scheduleTransmission(at: 2000, I2CTransmission(writeTo: 0x61, bytes: [0x03, 0x04]))
        master.scheduleTransmission(at: 2400, I2CTransmission(readFrom: 0x61, bytes: 2))
    }
}
