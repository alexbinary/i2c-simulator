
import SwiftUI



class Memory {
    
    let size: Int
    var bytes: [Byte] = []
    
    init(size: Int) {
        self.size = size
    }
    
    func write(atAddress baseAddress: Int, _ bytesToWrite: [Byte]) {
        var address = baseAddress
        for byte in bytesToWrite {
            bytes[address] = byte
            address += 1
        }
    }
    
    func read(fromAddress baseAddress: Int, size: Int) -> [Byte] {
        return [Byte](bytes[baseAddress..<(baseAddress+size)])
    }
}
