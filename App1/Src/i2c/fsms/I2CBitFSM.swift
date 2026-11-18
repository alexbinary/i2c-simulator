
import SwiftUI



enum I2CBitFSMState {
    
    case setup
    case clockHigh

    static var initialState: I2CBitFSMState { .setup }
}


class I2CBitFSM {
    
    private(set) var currentState: I2CBitFSMState = .initialState
    private(set) var readBit: Bit!
    
    
    init() {
        reset()
    }
    
    
    func reset() {
        currentState = .initialState
        readBit = nil
    }
    

    func update(
        
        afterLineChange changedLine: I2CBusLineEnum, updatedBusState: I2CBusFSMState, updatedLineLevels: (SDA: LineLevel, SCL: LineLevel),
        onSuccess: (Bit) -> (), onError: () -> ()
    
    ) {

        func success() {
            let bit = readBit!
            reset()
            onSuccess(bit)
        }
        
        func error() {
            reset()
            onError()
        }

        switch currentState {
        case .setup:

            if updatedBusState == .transmitting_LH || updatedBusState == .transmitting_HH {
                currentState = .clockHigh
            } else if updatedBusState != .started_LH && updatedBusState != .transmitting_HL && updatedBusState != .transmitting_LL {
                error()
            }

        case .clockHigh:

            if updatedBusState == .transmitting_LL || updatedBusState == .transmitting_HL {
                success()
            } else if updatedBusState != .transmitting_LH && updatedBusState != .transmitting_HH {
                error()
            }

            readBit = updatedLineLevels.SDA == .high ? .one : .zero
        }
        
        update_stabilize(onSuccess: onSuccess, onError: onError)
    }
    
    
    func update_stabilize(onSuccess: (Bit) -> (), onError: () -> ()) {
        
        while true {
            
            let stateBefore = currentState
            
            switch currentState {
            case .setup:
                break
            case .clockHigh:
                break
            }
            
            if currentState != stateBefore {
                continue
            } else {
                break
            }
        }
    }
}

