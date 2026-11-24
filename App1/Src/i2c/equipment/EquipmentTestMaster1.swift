
import SwiftUI



class EquipmentTestMaster1: I2CEquipment, I2CMasterController.Interrupts {
    
    
    lazy var i2cController = I2CMasterController(delegate: self)
    
    
    var slave1_testData1 = 0
    var slave1_testData2 = 0
    var slave2_testData1 = 0
    
    let slave1_address: Byte = 0x2a
    let slave2_address: Byte = 0x61
    
    let slave1_testData1_registerAddress = 0x00
    let slave1_testData1_len = 1
    let slave1_testData2_registerAddress = 0x01
    let slave1_testData2_len = 1
    let slave2_testData1_registerAddress = 0x03
    let slave2_testData1_len = 2
    
    var lastAddressedRegister: Int? = nil
    
    
    var transmittedBytes: [Byte] = []
    
    
    func reset(x: CGFloat) {
        
        i2cController.reset(x: x)
        read_slave2_testData1()
    }
    
    
    func update(x: CGFloat) {
        
        i2cController.update(x: x)
    }
    
    
    func connect(to bus: I2CBus) {
        
        i2cController.connect(to: bus)
    }
    
    
    func read_slave1_testData1() {
        
//        i2cMasterController.scheduleTransmission(at: 1, I2CTransmission(writeTo: slave1_address, bytes: [Byte(slave1_testData1_registerAddress)]))
//        i2cMasterController.scheduleTransmission(at: 2, I2CTransmission(readFrom: slave1_address, bytes: slave1_testData1_len))
    }
    
    
    func read_slave1_testData2() {
        
//        i2cMasterController.scheduleTransmission(at: 1, I2CTransmission(writeTo: slave1_address, bytes: [Byte(slave1_testData2_registerAddress)]))
//        i2cMasterController.scheduleTransmission(at: 2, I2CTransmission(readFrom: slave1_address, bytes: slave1_testData2_len))
    }
    
    
    func read_slave2_testData1() {
        
//        i2cMasterController.scheduleTransmission(at: 1, I2CTransmission(writeTo: slave2_address, bytes: [Byte(slave2_testData1_registerAddress)]))
//        i2cMasterController.scheduleTransmission(at: 2, I2CTransmission(readFrom: slave2_address, bytes: slave2_testData1_len))
    }
    
    
    func transmissionStarted() {
        
    }
    
    
    func nextDataByteToWrite() -> Byte? {
        
        nil
    }
    
    
    func sentDataByte(_ byte: Byte) {
        
        transmittedBytes.append(byte)
    }
    
    
    func receivedDataByte(_ byte: Byte) {
        
        transmittedBytes.append(byte)
    }
    
    
    func shouldContinueReadingDataBytes() -> Bool {
        
        false
    }
    
    
    func shouldHoldBeforeNextDataByte() -> Bool {
        
        false
    }
    
    
    func transmissionEnded(withResult result: TransmissionResult) {
        
        print("")
        print("-- EquipmentTestMaster1 TRANSMISSION ENDED --")
        print("\(result.type), address: \(result.address)+\(result.mode), transmittedBytes: \(transmittedBytes)")
        
        if result.isWrite {
            
            if result.isSuccess {
                
                let registerAddress = Int(transmittedBytes.first!)
                lastAddressedRegister = registerAddress
                
            } else {
                print("command failed")
            }
            
        } else if result.isRead {
            
            if result.isSuccess {
                
                let bytes = transmittedBytes
                switch result.address {
                case slave1_address:
                    switch lastAddressedRegister {
                    case 0x00:
                        slave1_testData1 = readBytes(bytes, len: slave1_testData1_len)
                        print("updated slave1_testData1: \(slave1_testData1)")
                    case 0x02:
                        slave1_testData2 = readBytes(bytes, len: slave1_testData2_len)
                        print("updated slave1_testData2: \(slave1_testData2)")
                    default:
                        break
                    }
                case slave2_address:
                    switch lastAddressedRegister {
                    case 0x03:
                        slave2_testData1 = readBytes(bytes, len: slave2_testData1_len)
                        print("updated slave2_testData1: \(slave2_testData1)")
                    default:
                        break
                    }
                default:
                    break
                }
                
            } else {
                
                print("read failed")
            }
        }
        
        transmittedBytes = []
    }
    
    
    func readBytes(_ bytes: [Byte], len: Int) -> Int {
        
        var res = 0
        
        for i in 0..<len {
            res += Int(bytes[i]) << (8*i)
        }
        
        return res
    }
}
