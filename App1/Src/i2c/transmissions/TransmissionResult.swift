
import SwiftUI



struct TransmissionResult {
    
    enum `Type` {
        case success
        case dataNack
        case aborted
        case transmissionRefused
    }
    let type: `Type`
    let address: Byte?
    let mode: ReadWrite?
}

extension TransmissionResult {
    
    var isSuccess: Bool { return type == .success }
    
    var isRead: Bool { return mode == .readFromSlave }
    var isWrite: Bool { return mode == .writeToSlave }
    
    var isWriteSuccess: Bool { return type == .success && mode == .writeToSlave }
    var isReadSuccess: Bool { return type == .success && mode == .readFromSlave }
}
