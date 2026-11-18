
import SwiftUI



class EquipmentTestSlave1: Equipment {
    
    let slave: I2CSlaveController
    
    init() {
        self.slave = I2CSlaveController(
            address: 0x2a,
            acceptWrites: true,
            acceptReads: false,
            onWriteSuccess: { writtenBytes in
                print("-- EquipmentTestSlave1 WRITE DONE --")
                print("written bytes: \(writtenBytes)")
            }
        )
        super.init(i2cController: slave)
    }
}
