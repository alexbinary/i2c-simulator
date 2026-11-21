
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
