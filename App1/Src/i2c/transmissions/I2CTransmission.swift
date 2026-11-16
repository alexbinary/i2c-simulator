
import SwiftUI



enum ReadWrite {

    case read, write
}


class I2CTransmission {
    
    let id = UUID()
    
    let address: UInt8
    let mode: ReadWrite
    var addressRW: UInt8 { (address << 1) + (mode == .read ? 1 : 0) }

    let bytes: [UInt8]
    let numBytes: Int

    
    init(writeTo address: UInt8, bytes: [UInt8]) {
        self.address = address
        self.mode = .write
        self.bytes = bytes
        self.numBytes = bytes.count
    }

    init(readFrom address: UInt8, bytes: Int) {
        self.address = address
        self.mode = .read
        self.bytes = []
        self.numBytes = bytes
    }
}
