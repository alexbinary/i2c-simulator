
import SwiftUI



class EquipmentTestSlave2: Equipment {
    
    let slave: I2CSlaveController
    
    init() {
        self.slave = I2CSlaveController(
            address: 0x61,
            acceptWrites: true,
            acceptReads: true,
            nextBytesToBeRead: {
                return []
            },
            onTransmissionEnded: { status in
                print("-- EquipmentTestSlave2 TRANSMISSION ENDED --")
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
