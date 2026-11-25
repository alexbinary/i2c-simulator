
import SwiftUI



class Fifo {
    
    let size: Int
    var bytes: [Byte]
    
    enum PushWhenFullBehavior { case discard, forcePush }
    var pushWhenFullBehavior: PushWhenFullBehavior
    
    var readIndex = 0
    var writeIndex = 0
    var isFull = false
    var isEmpty = true
    
    init(size: Int, pushWhenFullBehavior: PushWhenFullBehavior) {
        self.size = size
        self.bytes = [Byte](repeating: 0x00, count: size)
        self.pushWhenFullBehavior = pushWhenFullBehavior
    }
    
    func push(_ byte: Byte) {
        if !isFull || pushWhenFullBehavior == .forcePush {
            bytes[writeIndex] = byte
            writeIndex = (writeIndex + 1) % size
            if isFull {
                readIndex = writeIndex
            } else {
                isEmpty = false
                isFull = (writeIndex == readIndex)
            }
        }
    }
    
    func pop() -> Byte {
        guard !isEmpty else { return 0x00 }
        let index = readIndex
        readIndex = (readIndex + 1) % size
        isFull = false
        isEmpty = (readIndex == writeIndex)
        return bytes[index]
    }
    
    func peek() -> Byte? {
        guard !isEmpty else { return nil }
        return bytes[readIndex]
    }
    
    func clear() {
        readIndex = 0
        writeIndex = 0
        isFull = false
        isEmpty = true
    }
}
