
import SwiftUI



class EquipmentTestSlave2: Equipment {
    
    let slave: I2CSlaveController
    
    init() {
        self.slave = I2CSlaveController(
            address: 0x61,
            acceptWrites: false,
            acceptReads: true,
            nextBytesForMasterRead: {
                return []
            }
        )
        super.init(i2cController: slave)
    }
}
