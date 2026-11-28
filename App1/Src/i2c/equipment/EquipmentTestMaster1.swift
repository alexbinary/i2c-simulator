
import SwiftUI



class EquipmentTestMaster1: SimulationEntity, I2CBusConnectable {
    
    
    lazy var i2cController = I2CMasterController(name: "MAS")
    
    var markers: [SimulationMarker] = []
    
    
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
    
    
    func addMarker(_ x: CGFloat, _ color: Color) {
        
        markers.append(SimulationMarker(x: x, color: color))
    }

    
    func reset(x: CGFloat) {
        
        markers = []
        i2cController.reset(x: x)
    }
    
    
    func update(x: CGFloat) {
        
        var p: CGFloat = 0
        
        // test start timeout
        
        p += 1
        if x == p {
            prepare_request_slave2_testData1()
            i2cController.started = 1
            
            print("")
            print("\(x) -> 1/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
            addMarker(x, .blue)
        }
        
        // test start user abort
        
        p += 120
        if x == p {
            prepare_request_slave2_testData1()
            i2cController.started = 1
            
            print("")
            print("\(x) -> 2/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
            addMarker(x, .blue)
        }
        
//        p += 5
//        if x == p {
//            i2cController.started = 0
//            
//            print("")
//            print("\(x) -> 3/ aborting start")
//            addMarker(x, .blue)
//        }
//        
//        // test stretching and hold - timeout
//        
//        p += 5
//        if x == p {
//            prepare_request_slave2_testData1()
//            i2cController.stretching_enabled = 1
//            i2cController.hold_bus = 1
//            i2cController.started = 1
//            
//            print("")
//            print("\(x) -> 4/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
//            addMarker(x, .blue)
//        }
//        
//        // test stretching and hold - user disabled
//        
//        p += 1500
//        if x == p {
//            prepare_request_slave2_testData1()
//            i2cController.stretching_enabled = 1
//            i2cController.hold_bus = 1
//            i2cController.started = 1
//            
//            print("")
//            print("\(x) -> 5/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
//            addMarker(x, .blue)
//        }
//        
//        p += 350
//        if x == p {
//            i2cController.stretching_enabled = 0
//            
//            print("")
//            print("\(x) -> 6/ disabling stretching")
//            addMarker(x, .blue)
//        }
//        
//        p += 5
//        if x == p {
//            i2cController.stretching_enabled = 1
//            
//            print("")
//            print("\(x) -> 7/ enabling stretching")
//            addMarker(x, .blue)
//        }
//        
//        p += 350
//        if x == p {
//            i2cController.stretching_enabled = 0
//            
//            print("")
//            print("\(x) -> 8/ disabling stretching")
//            addMarker(x, .blue)
//        }
//        
//        p += 200
//        if x == p {
//            i2cController.hold_bus = 0
//            
//            print("")
//            print("\(x) -> 9/ disabling hold")
//            addMarker(x, .blue)
//        }
//        
//        // test stretching - fifo feed + no hold
//        
//        p += 400
//        if x == p {
//            prepare_request_slave2_testData1()
//            i2cController.stretching_enabled = 1
//            i2cController.hold_bus = 0
//            i2cController.started = 1
//            
//            print("")
//            print("\(x) -> 10/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
//            addMarker(x, .blue)
//        }
//        
//        p += 350
//        if x == p {
//            i2cController.txFifo.push(Byte(slave2_testData1_registerAddress))
//            
//            print("")
//            print("\(x) -> 11/ pushing data")
//            addMarker(x, .blue)
//        }
//        
//        p += 350
//        if x == p {
//            i2cController.txFifo.push(Byte(slave2_testData1_registerAddress))
//            
//            print("")
//            print("\(x) -> 12/ pushing data")
//            addMarker(x, .blue)
//        }
//        
//        // test no stretching + restart
//        
//        p += 300
//        if x == p {
//            prepare_request_slave2_testData1()
//            i2cController.stretching_enabled = 0
//            i2cController.hold_bus = 1
//            i2cController.started = 1
//            
//            print("")
//            print("\(x) -> 13/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
//            addMarker(x, .blue)
//        }
//        
//        p += 700
//        if x == p {
//            prepare_read_slave2_testData1()
//            i2cController.stretching_enabled = 0
//            i2cController.hold_bus = 0
//            i2cController.started = 1
//            
//            print("")
//            print("\(x) -> 14/ starting - stretching:\(i2cController.stretching_enabled), hold:\(i2cController.hold_bus)")
//            addMarker(x, .blue)
//        }
        
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
        i2cController.num_bytes = 1
        i2cController.stretching_enabled = 1
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
    }
    
    
    func processTransmissionResult() {
        
        print("")
        print("-- EquipmentTestMaster1 TRANSMISSION ENDED --")
        print("\(i2cController.result), address: \(i2cController.address)+\(i2cController.rw), num_bytes: \(i2cController.num_bytes)")

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
