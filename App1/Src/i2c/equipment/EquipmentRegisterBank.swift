
import SwiftUI



class EquipmentRegisterBank: Equipment, I2CSlaveController.Delegate {
    
    let i2cAddress: Byte
    var i2cSlaveController: I2CSlaveController { self.i2cController as! I2CSlaveController }
    
    var registers = [Byte](repeating: 0x00, count: 256)
    var registerBaseAddress: Int?
    var currentRegisterAddress: Int?
    
    var currentX: CGFloat = 0
    
    init(i2cAddress: Byte) {
        self.i2cAddress = i2cAddress
        super.init()
        self.i2cController = I2CSlaveController(respondsToAddresses: [i2cAddress], delegate: self)
    }
    
    
    override func reset(x: CGFloat) {
        super.reset(x: x)
        
        registers[3] = 12
        registers[4] = 1
    }
    
    
    override func update(x: CGFloat) {
        super.update(x: x)
        currentX = x
    }
    
    
    func shouldContinueHoldingBeforeDataByte(mode: ReadWrite) -> Bool {
        
        return mode == .readFromSlave && currentX < 2200
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
        print("-- EquipmentRegisterBank:\(i2cAddress) TRANSMISSION ENDED --")
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
