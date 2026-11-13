
import SwiftUI



enum I2CBusFSMState {
    
    case idle_HH
    case idle_HL
    case idle_LH
    case idle_LL
    
    case started_LH
    
    case transmitting_HH
    case transmitting_HL
    case transmitting_LH
    case transmitting_LL
}



class I2CBusFSM {
    
    
    var currentState: I2CBusFSMState = .idle_HH
    var isIdle: Bool { currentState == .idle_HH }


    func reset(levelSCL: LineLevel, levelSDA: LineLevel) {

        switch (levelSDA, levelSCL) {
        case (.high, .high): currentState = .idle_HH
        case (.high, .low): currentState = .idle_HL
        case (.low, .high): currentState = .idle_LH
        case (.low, .low): currentState = .idle_LL
        }
    }
    
 
    func update(changedLine: I2CBusLineEnum) {

        switch currentState {
            
        case .idle_HH:

            switch changedLine {
            case .SCL: currentState = .idle_HL
            case .SDA: currentState = .started_LH
            }
            
        case .idle_HL:
            
            switch changedLine {
            case .SCL: currentState = .idle_HH
            case .SDA: currentState = .idle_LL
            }

        case .idle_LH:

            switch changedLine {
            case .SCL: currentState = .idle_LL
            case .SDA: currentState = .idle_HH
            }
            
        case .idle_LL:

            switch changedLine {
            case .SCL: currentState = .idle_LH
            case .SDA: currentState = .idle_HL
            }
            
        case .started_LH:

            switch changedLine {
            case .SCL: currentState = .transmitting_LL
            case .SDA: currentState = .idle_HH
            }
            
        case .transmitting_HH:
            
            switch changedLine {
            case .SCL: currentState = .transmitting_HL
            case .SDA: currentState = .started_LH
            }
            
        case .transmitting_HL:
            
            switch changedLine {
            case .SCL: currentState = .transmitting_HH
            case .SDA: currentState = .transmitting_LL
            }
            
        case .transmitting_LH:
            
            switch changedLine {
            case .SCL: currentState = .transmitting_LL
            case .SDA: currentState = .idle_HH
            }
            
        case .transmitting_LL:
            
            switch changedLine {
            case .SCL: currentState = .transmitting_LH
            case .SDA: currentState = .transmitting_HL
            }
        }
    }
}
