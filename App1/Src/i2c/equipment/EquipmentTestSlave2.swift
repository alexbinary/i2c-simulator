
import SwiftUI



class EquipmentTestSlave2: Equipment {
    
    let i2cAddress: Byte
    var i2cSlaveController: I2CSlaveController { self.i2cController as! I2CSlaveController }
    
    init(i2cAddress: Byte) {
        self.i2cAddress = i2cAddress
        super.init()
        self.i2cController = I2CSlaveController(
            respondsToAddresses: [i2cAddress],
            reportsTransmissionsNotAddressedToSelf: true,
            acceptWrites: false,
            acceptReads: true,
            nextBytesToBeRead: {
                return []
            },
            onTransmissionEnded: { result in
                print("-- EquipmentTestSlave2 TRANSMISSION ENDED --")
                print("\(result.type), address: \(result.payload.address)+\(result.payload.mode), transmittedBytes: \(result.payload.transmittedBytes)")
            }
        )
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
        print("-- EquipmentTestSlave2 RESET: \(x) --")
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
        print("-- EquipmentTestSlave2 UPDATE: \(x) --")
    }
}
