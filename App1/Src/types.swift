
import SwiftUI



enum I2CBusLineLevel {
    
    case high, low
    
    var opposite: I2CBusLineLevel {
        switch self {
        case .high: return .low
        case .low: return .high
        }
    }
    
    var bit: Bit {
        switch self {
        case .high: return .one
        case .low: return .zero
        }
    }
}


enum Ack {
    
    case ack, nack
    
    init(from bit: Bit) {
        switch bit {
        case .zero: self = .ack
        case .one: self = .nack
        }
    }
    
    init(ackIf value: Bool) {
        self = value ? .ack : .nack
    }
    
    var bit: Bit {
        switch self {
        case .ack: return .zero
        case .nack: return .one
        }
    }
}


enum Bit {
    
    case zero, one

    init(_ value: Bool) {
        self = value ? .one : .zero
    }
    
    init(_ value: UInt8) {
        self.init(value != 0)
    }
    
    var lineLevel: I2CBusLineLevel {
        switch self {
        case .zero: return .low
        case .one: return .high
        }
    }
}


typealias Byte = UInt8
extension Byte {
    
    init(from bits:[Bit]) {
        self = bits
            .map { $0 == .zero ? 0 : 1 }
            .reduce(0, { byte, bit in (byte << 1) + bit })
    }
    
    func bit(atIndex bitIndex: Int) -> Bit {
        return Bit((self >> (7-bitIndex)) & 1)
    }
}
