
import SwiftUI



class EquipmentTestMaster1: Equipment, I2CMasterController.Delegate {
    
    var i2cMasterController: I2CMasterController { self.i2cController as! I2CMasterController }
    
    var transmissions: [I2CTransmission] = [
        
        I2CTransmission(readFrom: 0x2a, bytes: 1),
        
        I2CTransmission(writeTo: 0x2a, bytes: [0x00, 0x01]),
        I2CTransmission(writeTo: 0x2a, bytes: [0x00]),
        I2CTransmission(readFrom: 0x2a, bytes: 1),
        
        I2CTransmission(writeTo: 0x2a, bytes: [0x02, 0x01, 0x02]),
        I2CTransmission(writeTo: 0x2a, bytes: [0x02]),
        I2CTransmission(readFrom: 0x2a, bytes: 3),
    ]
    
    override init() {
        super.init()
        i2cController = I2CMasterController(delegate: self)
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
        activateNextTransmission()
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)

    }
    
    
    func activateNextTransmission() {
        
        guard !transmissions.isEmpty else { return }
        let transmission = transmissions.removeFirst()
        i2cMasterController.scheduleTransmission(at: 0, transmission)
    }
    
    
    func onTransmissionEnded(result: I2CMasterController.TransmissionResult) {
        
        print("")
        print("-- EquipmentTestMaster1 TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.address)+\(result.mode), transmittedBytes: \(result.transmittedBytes)")
        
        if result.type == .success, result.mode == .writeToSlave {
            print("sent command: \(result.transmittedBytes.first)")
        }
        if result.type == .success, result.mode == .readFromSlave {
            print("read values: \(result.transmittedBytes)")
        }
        
        self.activateNextTransmission()
    }
}
