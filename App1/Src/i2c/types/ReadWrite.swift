
import SwiftUI



enum ReadWrite {

    case writeToSlave, readFromSlave
    
    init(from bit: Bit) {
        switch bit {
        case .zero: self = .writeToSlave
        case .one: self = .readFromSlave
        }
    }
    
    var bit: Bit {
        switch self {
        case .writeToSlave: return .zero
        case .readFromSlave: return .one
        }
    }
}
