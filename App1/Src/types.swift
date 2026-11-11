
import SwiftUI



enum LineLevel {
    
    case high, low
    
    var opposite: LineLevel {
        switch self {
        case .high: return .low
        case .low: return .high
        }
    }
}


enum Bit {
    
    case zero, one
    
    var lineLevel: LineLevel {
        switch self {
        case .zero: return .low
        case .one: return .high
        }
    }
}
