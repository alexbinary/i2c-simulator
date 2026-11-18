
import SwiftUI



class EquipmentTestSlave1: Equipment {
    
    let slave: I2CSlaveController
    
    init() {
        self.slave = I2CSlaveController(
            address: 0x2a,
            acceptWrites: true,
            acceptReads: false,
            onTransmissionComplete: { writtenBytes in
                print("-- EquipmentTestSlave1 TRANSMISSION DONE --")
                print("written bytes: \(writtenBytes)")
            }
        )
        super.init(i2cController: slave)
    }
}
