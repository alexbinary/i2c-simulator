
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
                case .success(let bytesWrittenToSlave, let bytesReadFromSlave):
                    print("success, bytesWrittenToSlave: \(bytesWrittenToSlave), bytesReadFromSlave: \(bytesReadFromSlave)")
                case .dataNack(let bytesWrittenToSlave, let bytesReadFromSlave):
                    print("data nack, bytesWrittenToSlave: \(bytesWrittenToSlave), bytesReadFromSlave: \(bytesReadFromSlave)")
                case .aborted:
                    print("aborted")
                }
            }
        )
        super.init(i2cController: slave)
    }
}
