
import SwiftUI



class EquipmentTestSlave1: Equipment {
    
    let i2cAddress: Byte
    var i2cSlaveController: I2CSlaveController { self.i2cController as! I2CSlaveController }
    
    init(i2cAddress: Byte) {
        self.i2cAddress = i2cAddress
        super.init()
        self.i2cController = I2CSlaveController(respondsToAddresses: [i2cAddress], onTransmissionEnded: onTransmissionEnded)
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
    }
    
    func onTransmissionEnded(result: I2CSlaveController.TransmissionResult) {
        
        print("")
        print("-- EquipmentTestSlave1 TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.payload.address)+\(result.payload.mode), transmittedBytes: \(result.payload.transmittedBytes)")
    }
}
