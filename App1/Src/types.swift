
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

    init(_ value: Int) {

        if value == 0 {
            self = .zero
        } else {
            self = .one
        }
    }
    
    var lineLevel: LineLevel {
        switch self {
        case .zero: return .low
        case .one: return .high
        }
    }
}
