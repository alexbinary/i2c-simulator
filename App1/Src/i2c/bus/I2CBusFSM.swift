
import SwiftUI



enum I2CBusFSMMicroState {
    
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



enum I2CBusFSMMacroState {
    
    case idle
    case busy
}


class I2CBusFSM {
    
    
    var currentMicroState: I2CBusFSMMicroState = .idle_HH
    var currentMacroState: I2CBusFSMMacroState { currentMicroState == .idle_HH ? .idle : .busy }


    func reset(levelSCL: LineLevel, levelSDA: LineLevel) {

        switch (levelSDA, levelSCL) {
        case (.high, .high): currentMicroState = .idle_HH
        case (.high, .low): currentMicroState = .idle_HL
        case (.low, .high): currentMicroState = .idle_LH
        case (.low, .low): currentMicroState = .idle_LL
        }
    }
    
 
    func update(changedLine: I2CBusLineEnum) {

        currentMicroState = updatedMicroState(afterChangeOf: changedLine)
    }


    private func updatedMicroState(afterChangeOf changedLine: I2CBusLineEnum) -> I2CBusFSMMicroState {

        switch currentMicroState {
            
        case .idle_HH:

            switch changedLine {
            case .SCL: return .idle_HL
            case .SDA: return .started_LH
            }
            
        case .idle_HL:
            
            switch changedLine {
            case .SCL: return .idle_HH
            case .SDA: return .idle_LL
            }

        case .idle_LH:

            switch changedLine {
            case .SCL: return .idle_LL
            case .SDA: return .idle_HH
            }
            
        case .idle_LL:

            switch changedLine {
            case .SCL: return .idle_LH
            case .SDA: return .idle_HL
            }
            
        case .started_LH:

            switch changedLine {
            case .SCL: return .transmitting_LL
            case .SDA: return .idle_HH
            }
            
        case .transmitting_HH:
            
            switch changedLine {
            case .SCL: return .transmitting_HL
            case .SDA: return .started_LH
            }
            
        case .transmitting_HL:
            
            switch changedLine {
            case .SCL: return .transmitting_HH
            case .SDA: return .transmitting_LL
            }
            
        case .transmitting_LH:
            
            switch changedLine {
            case .SCL: return .transmitting_LL
            case .SDA: return .idle_HH
            }
            
        case .transmitting_LL:
            
            switch changedLine {
            case .SCL: return .transmitting_LH
            case .SDA: return .transmitting_HL
            }
        }
    }
}
