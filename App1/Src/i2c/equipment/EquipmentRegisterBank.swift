
import SwiftUI



class EquipmentRegisterBank: I2CEquipment {
    
    let i2cAddress: Byte
    lazy var i2cController = I2CSlaveController()
    
    var registers = [Byte](repeating: 0x00, count: 256)
    var registerBaseAddress: Int? = 3
    var currentRegisterAddress: Int? = 3
    
    var currentX: CGFloat = 0
    
    
    var transmittedBytes: [Byte] = []
    
    
    init(i2cAddress: Byte) {
        self.i2cAddress = i2cAddress
    }
    
    func reset(x: CGFloat) {
        
        i2cController.reset(x: x)
        
        registers[3] = 12+128
        registers[4] = 1
    }
    
    func update(x: CGFloat) {
        
        i2cController.update(x: x)
        
        currentX = x
    }
    
    
    func connect(to bus: I2CBus) {
        
        i2cController.connect(to: bus)
    }
    
    
    func shouldAcceptTransmission(with address: Byte, mode: ReadWrite) -> Bool {
        
        return address == self.i2cAddress
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
        
//        if currentRegisterAddress != nil {
//            
//            let byte = registers[currentRegisterAddress!]
//            currentRegisterAddress! += 1
//            return [byte]
//        }
        
        return nil
    }
    
    
    func shouldHoldBeforeNextDataByte(mode: ReadWrite) -> Bool {
        
        return mode == .readFromSlave && currentX < 1500
    }
    
    
    func shouldAckDataByte() -> Bool {
        
        true
    }
    
    
    func transmissionEnded(withResult result: TransmissionResult) {
        
        print("")
        print("-- EquipmentRegisterBank:\(i2cAddress) TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.address)+\(result.mode), transmittedBytes: \(transmittedBytes)")
        
        if result.isWriteSuccess {
            
            let bytes = transmittedBytes
            if bytes.count > 0 {
                
                registerBaseAddress = Int(transmittedBytes.first!)
                currentRegisterAddress = registerBaseAddress
                print("setting register address: \(registerBaseAddress)")
                
                if bytes.count > 1 {
                    
                    let data = transmittedBytes[1...]
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
            
            print("sent values: \(transmittedBytes)")
        }
        
        transmittedBytes = []
    }
}
