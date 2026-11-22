
import SwiftUI



class EquipmentTestSlave1: Equipment, I2CSlaveController.Delegate {
    
    let i2cAddress: Byte
    var i2cSlaveController: I2CSlaveController { self.i2cController as! I2CSlaveController }
    
    var registers = [Byte](repeating: 0x00, count: 256)
    var registerBaseAddress: Int?
    var currentRegisterAddress: Int?
    
    init(i2cAddress: Byte) {
        self.i2cAddress = i2cAddress
        super.init()
        self.i2cController = I2CSlaveController(respondsToAddresses: [i2cAddress], delegate: self)
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        
    }
    
    
    func nextBytesToBeRead() -> [Byte] {
        
        if currentRegisterAddress != nil {
            
            let byte = registers[currentRegisterAddress!]
            currentRegisterAddress! += 1
            return [byte]
        }
        
        return []
    }
    
    
    func onTransmissionEnded(result: I2CSlaveController.TransmissionResult) {
        
        print("")
        print("-- EquipmentTestSlave1 TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.address)+\(result.mode), transmittedBytes: \(result.transmittedBytes)")
        
        if result.isWriteSuccess {
            
            let bytes = result.transmittedBytes
            if bytes.count > 0 {
                
                registerBaseAddress = Int(result.transmittedBytes.first!)
                currentRegisterAddress = registerBaseAddress
                print("setting register address: \(registerBaseAddress)")
                
                if bytes.count > 1 {
                    
                    let data = result.transmittedBytes[1...]
                    var baseAddress = registerBaseAddress!
                    for byte in data {
                        
                        registers[baseAddress] = byte
                        print("wrote register: [\(baseAddress)]=\(registers[baseAddress])")
                        baseAddress += 1
                    }
                }
                
            } else {
                print("ERROR: no register address")
            }
        }
        
        if result.type == .success, result.mode == .readFromSlave {
            
            print("sent values: \(result.transmittedBytes)")
        }
    }
}
