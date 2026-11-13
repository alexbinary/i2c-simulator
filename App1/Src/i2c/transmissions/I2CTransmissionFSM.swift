
import SwiftUI



enum I2CTransmissionFSMState {
    
    case sendingStart
    case writingAddressRW
    case readingAddressAck
    case readyData
    case transmittingByte
    case transmittingByteAck
    case sendingStop
    case done
}


class I2CTransmissionFSM {
    
    
    var currentState: I2CTransmissionFSMState = .sendingStart
    
    
    func reset() {
        
        currentState = .sendingStart
    }
    
    func sendingStart() {
        
        if currentState == .readyData {
            currentState = .sendingStart
        }
    }
    
    func startSent() {
        
        if currentState == .sendingStart {
            currentState = .writingAddressRW
        }
    }
    
    func addressRWSent() {
        
        if currentState == .writingAddressRW {
            currentState = .sendingStop//.readingAddressAck
        }
    }
    
    func transmittingByte() {
        
        if currentState == .readyData {
            currentState = .transmittingByte
        }
    }
    
    func byteSent() {
        
        if currentState == .transmittingByte {
            currentState = .transmittingByteAck
        }
    }
    
    func ack() {
        
        if currentState == .readingAddressAck {
            currentState = .readyData
        }
        if currentState == .transmittingByteAck {
            currentState = .readyData
        }
    }
    
    func nack() {
        
        if currentState == .readingAddressAck {
            currentState = .sendingStop
        }
        if currentState == .transmittingByteAck {
            currentState = .sendingStop
        }
    }
    
    func sendingStop() {
        
        if currentState == .readyData {
            currentState = .sendingStop
        }
    }
    
    func stopSent() {
        
        if currentState == .sendingStop {
            currentState = .done
        }
    }

    func abort() {
        
        currentState = .done
    }
}
