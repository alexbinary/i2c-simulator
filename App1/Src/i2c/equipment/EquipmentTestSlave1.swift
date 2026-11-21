
import SwiftUI



class EquipmentTestSlave1: Equipment {
    
    let slave: I2CSlaveController
    
    init() {
        self.slave = I2CSlaveController(
            address: 0x2a,
            acceptWrites: true,
            acceptReads: false,
//            maxWrites: 1,
            onTransmissionEnded: { status in
                print("-- EquipmentTestSlave1 TRANSMISSION ENDED --")
                switch status {
                case .success(let writtenBytes, let readBytes):
                    print("success, written: \(writtenBytes), read: \(readBytes)")
                case .dataNack(let writtenBytes, let readBytes):
                    print("data nack, written: \(writtenBytes), read: \(readBytes)")
                case .aborted:
                    print("aborted")
                }
            }
        )
        super.init(i2cController: slave)
    }
}
