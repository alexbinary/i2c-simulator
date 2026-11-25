
import SwiftUI



class EquipmentRegisterBank: I2CEquipment {
    
    let i2cAddress: Byte
    lazy var i2cController = I2CSlaveController()
    
    var registers = [Byte](repeating: 0x00, count: 256)
    var registerBaseAddress: Int = 0
    var currentRegisterAddress: Int = 0
    
    
    var transmissionOngoing = false
    
    
    init(i2cAddress: Byte) {
        
        self.i2cAddress = i2cAddress
    }
    
    
    func reset(x: CGFloat) {
        
        registers[3] = 12+128
        registers[4] = 1
        
        i2cController.reset(x: x)
        i2cController.addresses = [i2cAddress]
        i2cController.last_address_index = 0
        i2cController.stretching_enabled = 1
        i2cController.spy_mode = 0
    }
    
    
    func update(x: CGFloat) {
        
        i2cController.update(x: x)
        
        if !transmissionOngoing {
            if i2cController.started == 1 {
                transmissionOngoing = true
                transmissionStarted()
            }
        }
        if transmissionOngoing {
            if i2cController.started == 0 {
                transmissionOngoing = false
                transmissionEnded()
            }
            if i2cController.stretching_ongoing == 1 {
                stretchingOngoing()
            }
        }
    }
    
    
    func connect(to bus: I2CBus) {
        
        i2cController.connect(to: bus)
    }
    
    
    func transmissionStarted() {
        
    }
    
    
    func stretchingOngoing() {
        
        if i2cController.rw == .readFromSlave {
            
            let byte = registers[currentRegisterAddress]
            i2cController.txFifo.push(byte)
            currentRegisterAddress += 1
        }
    }

    
    func transmissionEnded() {
        
        print("")
        print("-- EquipmentRegisterBank:\(i2cAddress) TRANSMISSION ENDED --")
        print("\(i2cController.result), address: \(i2cController.address)+\(i2cController.rw)")

        if i2cController.result == .success && i2cController.rw == .writeToSlave {
            writeSuccess()
        }
        
        if i2cController.result == .success, i2cController.rw == .readFromSlave {
            readSuccess()
        }
    }
    
    
    func writeSuccess() {
        
        guard i2cController.num_bytes > 0 else {
            print("ERROR: no register address")
            return
        }
        
        registerBaseAddress = Int(i2cController.rxFifo.pop())
        currentRegisterAddress = registerBaseAddress
        print("setting register address: \(registerBaseAddress)")
        
        guard i2cController.num_bytes > 1 else {
            print("ERROR: no data")
            return
        }
        
        var baseAddress = registerBaseAddress
        for _ in 1..<i2cController.num_bytes {
            let byte = i2cController.rxFifo.pop()
            registers[baseAddress] = byte
            print("wrote register: [\(baseAddress)]=\(registers[baseAddress])")
            baseAddress += 1
        }
        
        i2cController.rxFifo.clear()
    }
    
    
    func readSuccess() {
        
        print("read success: \(i2cController.num_bytes)")
    }
}
