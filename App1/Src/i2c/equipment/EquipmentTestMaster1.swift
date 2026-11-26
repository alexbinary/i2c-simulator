
import SwiftUI



class EquipmentTestMaster1: I2CBusConnectable {
    
    
    lazy var i2cController = I2CMasterController()
    
    
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
    
    var transmissionStarted = false
    var lastAddressedRegister: Int? = nil

    
    func reset(x: CGFloat) {
        
        i2cController.reset(x: x)
        prepare_request_slave2_testData1()
    }
    
    
    func update(x: CGFloat) {
        
        if x == 1 {
            i2cController.started = 1
        }
        
        if x == 1200 {
            i2cController.started = 1
        }
        
        if x == 1205 {
            i2cController.started = 0
        }
        
        if x == 1210 {
            i2cController.started = 1
        }
        
        i2cController.update(x: x)
        
        if !transmissionStarted {
            if i2cController.started == 1 {
                transmissionStarted = true
            }
        }
        
        if transmissionStarted {
            if i2cController.started == 0 {
                transmissionStarted = false
                processTransmissionResult()
            }
        }
    }
    
    
    func connect(to bus: I2CBus) {
        
        i2cController.connect(to: bus)
    }
    
    
    func prepare_request_slave2_testData1() {
        
        i2cController.address = slave2_address
        i2cController.rw = .writeToSlave
        i2cController.txFifo.clear()
        i2cController.txFifo.push(Byte(slave2_testData1_registerAddress))
        i2cController.num_bytes = 1
        i2cController.stretching_enabled = 0
        i2cController.hold_bus = 1
        
        lastAddressedRegister = slave2_testData1_registerAddress
    }
    
    
    func prepare_read_slave2_testData1() {
        
        i2cController.address = slave2_address
        i2cController.rw = .readFromSlave
        i2cController.rxFifo.clear()
        i2cController.num_bytes = slave2_testData1_len
        i2cController.stretching_enabled = 0
        i2cController.hold_bus = 0
        
        i2cController.started = 1
        transmissionStarted = true
    }
    
    
    func processTransmissionResult() {
        
        print("")
        print("-- EquipmentTestMaster1 TRANSMISSION ENDED --")
        print("\(i2cController.result), address: \(i2cController.address)+\(i2cController.rw)")

        if i2cController.rw == .writeToSlave {

            if i2cController.result == .success {
                requestRegisterSuccess()
            } else {
                print("command failed")
            }
        }
        if i2cController.rw == .readFromSlave {
            
            if i2cController.result == .success {
                readRegisterSuccess()
            } else {
                print("read failed")
            }
        }
    }
    
    
    func requestRegisterSuccess() {
        
        prepare_read_slave2_testData1()
    }
    
    
    func readRegisterSuccess() {
        
        switch i2cController.address {
        case slave1_address:
            switch lastAddressedRegister {
            case 0x00:
                slave1_testData1 = readWord(i2cController.rxFifo, len: slave1_testData1_len)
                print("updated slave1_testData1: \(slave1_testData1)")
            case 0x02:
                slave1_testData2 = readWord(i2cController.rxFifo, len: slave1_testData2_len)
                print("updated slave1_testData2: \(slave1_testData2)")
            default:
                break
            }
        case slave2_address:
            switch lastAddressedRegister {
            case 0x03:
                slave2_testData1 = readWord(i2cController.rxFifo, len: slave2_testData1_len)
                print("updated slave2_testData1: \(slave2_testData1)")
            default:
                break
            }
        default:
            break
        }
    }
    
    
    func readWord(_ fifo: Fifo, len: Int) -> Int {
        
        var res = 0
        
        for i in 0..<len {
            let byte = i2cController.rxFifo.pop()
            res += Int(byte) << (8*i)
        }
        
        return res
    }
}
