
import SwiftUI



class I2CTransmission {
    
    let addressRW: UInt8
    let bytes: [UInt8]
    
    init(
        addressRW: UInt8,
        bytes: [UInt8]
    ) {
        self.addressRW = addressRW
        self.bytes = bytes
    }
}
