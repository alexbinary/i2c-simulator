
import SwiftUI



enum Bit {
    
    case zero, one

    init(_ value: Bool) {
        self = value ? .one : .zero
    }
    
    init(_ value: UInt8) {
        self.init(value != 0)
    }
    
    init(for ack: Ack) {
        self = ack.bit
    }
    
    var lineLevel: I2CBusLineLevel {
        switch self {
        case .zero: return .low
        case .one: return .high
        }
    }
}
