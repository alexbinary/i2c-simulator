
import SwiftUI



class EquipmentTestSlave1: Equipment {
    
    let slave = I2CSlaveController(address: 0x2a, acceptWrites: true, acceptReads: false, maxWrites: 1)
    
    init() {
        super.init(i2cController: slave)
    }
}
