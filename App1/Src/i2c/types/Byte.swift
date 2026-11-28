
import SwiftUI



typealias Byte = UInt8
extension Byte {
    
    init(from bits:[Bit]) {
        self = bits
            .map { $0 == .zero ? 0 : 1 }
            .reduce(0, { byte, bit in (byte << 1) + bit })
    }
    
    func bit(atTransmissionIndex bitIndex: Int) -> Bit {
        return Bit((self >> (7-bitIndex)) & 1)
    }
}
