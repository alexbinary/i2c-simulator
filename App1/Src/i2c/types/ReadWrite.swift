
import SwiftUI



enum ReadWrite {

    case writeToSlave, readFromSlave
    
    init(from bit: Bit) {
        switch bit {
        case .zero: self = .writeToSlave
        case .one: self = .readFromSlave
        }
    }
}
