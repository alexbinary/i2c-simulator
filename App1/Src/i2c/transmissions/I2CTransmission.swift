
import SwiftUI



enum ReadWrite {

    case writeToSlave, readFromSlave
}


class I2CTransmission {
    
    let id = UUID()
    
    let address: UInt8
    let mode: ReadWrite
    var addressRW: UInt8 { (address << 1) + (mode == .readFromSlave ? 1 : 0) }
    var isReadFromSlave: Bool { return mode == .readFromSlave }
    var isWriteToSlave: Bool { return mode == .writeToSlave }

    let bytes: [UInt8]
    let numBytes: Int

    
    init(writeTo address: UInt8, bytes: [UInt8]) {
        self.address = address
        self.mode = .writeToSlave
        self.bytes = bytes
        self.numBytes = bytes.count
    }

    init(readFrom address: UInt8, bytes: Int) {
        self.address = address
        self.mode = .readFromSlave
        self.bytes = []
        self.numBytes = bytes
    }
}
