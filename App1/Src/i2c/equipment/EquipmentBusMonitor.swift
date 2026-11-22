
import SwiftUI



class EquipmentBusMonitor: Equipment, I2CSlaveController.Delegate {
    
    var i2cSlaveController: I2CSlaveController { self.i2cController as! I2CSlaveController }
    
    override init() {
        super.init()
        self.i2cController = I2CSlaveController(
            respondsToAddresses: [],
            reportsTransmissionsNotAddressedToSelf: true,
            delegate: self
        )
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
    }
    
    
    func onTransmissionEnded(result: I2CSlaveController.TransmissionResult) {
        
        print("")
        print("-- EquipmentBusMonitor TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.address)+\(result.mode), transmittedBytes: \(result.transmittedBytes)")
    }
}
