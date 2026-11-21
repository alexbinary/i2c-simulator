
import SwiftUI



class EquipmentTestSlave2: Equipment {
    
    let slave: I2CSlaveController
    
    init() {
        self.slave = I2CSlaveController(
            address: 0x61,
            acceptWrites: false,
            acceptReads: true,
            nextBytesToBeRead: {
                return []
            },
            onTransmissionEnded: { status in
                print("-- EquipmentTestSlave2 TRANSMISSION ENDED --")
                switch status {
                case .success(let transmittedBytes):
                    print("success, transmittedBytes: \(transmittedBytes)")
                case .dataNack(let transmittedBytes):
                    print("data nack, transmittedBytes: \(transmittedBytes)")
                case .aborted(let transmittedBytes):
                    print("aborted, transmittedBytes: \(transmittedBytes)")
                }
            }
        )
        super.init(i2cController: slave)
    }
}
