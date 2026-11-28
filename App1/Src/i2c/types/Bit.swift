
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
    
    static func ackIf(_ value: Bool) -> Bit {
        return Ack(ackIf: value).bit
    }
    
    var value: UInt8 {
        switch self {
        case .zero: return 0
        case .one: return 1
        }
    }
    
    var ack: Ack {
        switch self {
        case .zero: return .ack
        case .one: return .nack
        }
    }
    
    var isAck: Bool {
        self.ack == .ack
    }
    
    var isNack: Bool {
        self.ack == .nack
    }
    
    static var ack: Bit { Ack.ack.bit }
    static var nack: Bit { Ack.nack.bit }
}
