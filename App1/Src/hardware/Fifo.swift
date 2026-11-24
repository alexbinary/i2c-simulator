
import SwiftUI



class Fifo {
    
    let size: Int
    var bytes: [Byte]
    var readIndex = 0
    var writeIndex = 0
    var isFull = false
    var isEmpty = true
    
    init(size: Int) {
        self.size = size
        self.bytes = [Byte](repeating: 0x00, count: size)
    }
    
    func push(_ byte: Byte) -> Bool {
        guard !isFull else { return false }
        bytes[writeIndex] = byte
        writeIndex = (writeIndex + 1) % size
        isEmpty = false
        if writeIndex == readIndex { isFull = true }
        return true
    }
    
    func pop() -> Byte? {
        guard !isEmpty else { return nil }
        let index = readIndex
        readIndex = (readIndex + 1) % size
        isFull = false
        if readIndex == writeIndex { isEmpty = true }
        return bytes[index]
    }
    
    func peek() -> Byte? {
        guard !isEmpty else { return nil }
        return bytes[readIndex]
    }
}
