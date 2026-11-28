
import SwiftUI



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
