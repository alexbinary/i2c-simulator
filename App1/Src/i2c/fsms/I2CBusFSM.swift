
import SwiftUI



enum I2CBusFSMMicroState {
    
    case undef
    
    case idle_HH
    case idle_HL
    case idle_LH
    case idle_LL
    
    case started
    
    case transmitting_HH
    case transmitting_HL
    case transmitting_LH
    case transmitting_LL
}



enum I2CBusFSMMacroState {
    
    case undef
    case idle
    case busy
}


class I2CBusFSM {
    
    
    var currentMicroState: I2CBusFSMMicroState = .undef
    
    
    var currentMacroState: I2CBusFSMMacroState {
        
        switch currentMicroState {
            
        case .undef:
            return .undef
            
        case .idle_HH:
            return .idle
            
        case .idle_HL:
            return .busy
            
        case .idle_LH:
            return .busy
            
        case .idle_LL:
            return .busy
            
        case .started:
            return .busy
            
        case .transmitting_HH:
            return .busy
        
        case .transmitting_HL:
            return .busy
        
        case .transmitting_LH:
            return .busy
        
        case .transmitting_LL:
            return .busy
        }
    }
    
 
    func update(levelSCL: LineLevel, levelSDA: LineLevel) {
        
        currentMicroState = getNextMicroState(levelSCL: levelSCL, levelSDA: levelSDA, currentMicroState: currentMicroState)
    }
    
    
    private func getNextMicroState(levelSCL: LineLevel, levelSDA: LineLevel, currentMicroState: I2CBusFSMMicroState) -> I2CBusFSMMicroState {
        
        switch currentMicroState {
            
        case .undef:
            
            switch (levelSCL, levelSDA) {
                
            case (.high, .high):
                return .idle_HH
                
            case (.high, .low):
                return .idle_HL
                
            case (.low, .high):
                return .idle_LH
                
            case (.low, .low):
                return .idle_LL
            }
            
        case .idle_HH:
            
            if levelSDA == .low, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .low {
                return .started
            }
            
            if levelSCL == .low {
                return .idle_HL
            }
        
        case .idle_HL:
            
            if levelSDA == .low, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .low {
                return .idle_LL
            }
            
            if levelSCL == .high {
                return .idle_HH
            }
        
        case .idle_LH:
            
            if levelSDA == .high, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_HH
            }
            
            if levelSCL == .low {
                return .idle_LL
            }
        
        case .idle_LL:
            
            if levelSDA == .high, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_HL
            }
            
            if levelSCL == .high {
                return .idle_LH
            }
            
        case .started:
            
            if levelSDA == .high, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_HL
            }
            
            if levelSCL == .low {
                return .transmitting_LL
            }
            
        case .transmitting_HH:
            
            if levelSDA == .low, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .low {
                return .started
            }
            
            if levelSCL == .low {
                return .transmitting_HL
            }
            
        case .transmitting_HL:
            
            if levelSDA == .low, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .low {
                return .transmitting_LL
            }
            
            if levelSCL == .high {
                return .transmitting_HH
            }
        
        case .transmitting_LH:
            
            if levelSDA == .high, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_HH
            }
            
            if levelSCL == .low {
                return .transmitting_LL
            }
        
        case .transmitting_LL:
            
            if levelSDA == .high, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .high {
                return .transmitting_HL
            }
            
            if levelSCL == .high {
                return .transmitting_LH
            }
        }
        
        return currentMicroState
    }
}
