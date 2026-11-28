
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
