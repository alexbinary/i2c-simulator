
import SwiftUI



class EquipmentTestSlave1: Equipment {
    
    let i2cAddress: Byte
    var i2cSlaveController: I2CSlaveController { self.i2cController as! I2CSlaveController }
    
    init(i2cAddress: Byte) {
        self.i2cAddress = i2cAddress
        super.init(i2cController: I2CSlaveController(
            address: i2cAddress,
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
        ))
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
        print("-- EquipmentTestSlave1 RESET: \(x) --")
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
        print("-- EquipmentTestSlave1 UPDATE: \(x) --")
    }
}
