
import SwiftUI



class EquipmentBusMonitor: I2CEquipment, I2CSlaveController.Delegate {
    
    lazy var i2cController = I2CSlaveController(delegate: self)
    
    var transmittedBytes: [Byte] = []
    
    
    init() {
//        self.i2cController = I2CSlaveController(delegate: self)
    }
    
    func reset(x: CGFloat) {
        
        i2cController.reset(x: x)
    }
    
    func update(x: CGFloat) {
        
        i2cController.update(x: x)
    }
    
    func connect(to bus: I2CBus) {
        
        i2cController.connect(to: bus)
    }
    
    func shouldAcceptTransmission(with address: Byte, mode: ReadWrite) -> Bool {
        
        return false
    }
    
    func transmissionStarted(with address: Byte, mode: ReadWrite) {
    
    }
    
    func receivedDataByte(_ byte: Byte) {
        
        transmittedBytes.append(byte)
    }
    
    func sentDataByte(_ byte: Byte) {
        
        transmittedBytes.append(byte)
    }
    
    func nextDataByteToBeRead() -> Byte? {
        
        nil
    }
    
    func shouldHoldBeforeNextDataByte(mode: ReadWrite) -> Bool {
        
        false
    }
    
    func shouldAckDataByte() -> Bool {
        
        false
    }
    
    func transmissionEnded(withResult: TransmissionResult) {
        
        print("")
        print("-- EquipmentBusMonitor TRANSMISSION ENDED --")
        print("\(withResult.type), address: \(withResult.address)+\(withResult.mode), transmittedBytes: \(transmittedBytes)")
        
        transmittedBytes = []
    }
}
