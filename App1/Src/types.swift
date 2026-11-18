
import SwiftUI



enum I2CLineLevel {
    
    case high, low
    
    var opposite: I2CLineLevel {
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


struct I2CBusLineLevels: Equatable {
    
    let SCL: I2CLineLevel
    let SDA: I2CLineLevel
    
    func match(SCL: I2CLineLevel, SDA: I2CLineLevel) -> Bool {
        
        return self.SCL == SCL && self.SDA == SDA
    }
 
    func updated(afterLineChange changedLine: I2CBusLineEnum) -> I2CBusLineLevels {
        
        switch changedLine {
        case .SCL:
            return I2CBusLineLevels(SCL: SCL.opposite, SDA: SDA)
        case .SDA:
            return I2CBusLineLevels(SCL: SCL, SDA: SDA.opposite)
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
    
    var lineLevel: I2CLineLevel {
        switch self {
        case .zero: return .low
        case .one: return .high
        }
    }
}


typealias Byte = UInt8
extension Byte {
    
    func bit(atIndex bitIndex: Int) -> Bit {
        return Bit((self >> (7-bitIndex)) & 1)
    }
}
