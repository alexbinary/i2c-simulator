
import SwiftUI



enum I2CBusFSMMicroState {
    
    case undef
    
    case idle_SDAH_SCLH
    case idle_SDAH_SCLL
    case idle_SDAL_SCLH
    case idle_SDAL_SCLL
    
    case started
    
    case started_SDAH_SCLH
    case started_SDAH_SCLL
    case started_SDAL_SCLH
    case started_SDAL_SCLL
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
            
        case .idle_SDAH_SCLH:
            return .idle
            
        case .idle_SDAH_SCLL:
            return .busy
            
        case .idle_SDAL_SCLH:
            return .busy
            
        case .idle_SDAL_SCLL:
            return .busy
            
        case .started:
            return .busy
            
        case .started_SDAH_SCLH:
            return .busy
        
        case .started_SDAH_SCLL:
            return .busy
        
        case .started_SDAL_SCLH:
            return .busy
        
        case .started_SDAL_SCLL:
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
                return .idle_SDAH_SCLH
                
            case (.high, .low):
                return .idle_SDAH_SCLL
                
            case (.low, .high):
                return .idle_SDAL_SCLH
                
            case (.low, .low):
                return .idle_SDAL_SCLL
            }
            
        case .idle_SDAH_SCLH:
            
            if levelSDA == .low, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .low {
                return .started
            }
            
            if levelSCL == .low {
                return .idle_SDAH_SCLL
            }
        
        case .idle_SDAH_SCLL:
            
            if levelSDA == .low, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .low {
                return .idle_SDAL_SCLL
            }
            
            if levelSCL == .high {
                return .idle_SDAH_SCLH
            }
        
        case .idle_SDAL_SCLH:
            
            if levelSDA == .high, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_SDAH_SCLH
            }
            
            if levelSCL == .low {
                return .idle_SDAL_SCLL
            }
        
        case .idle_SDAL_SCLL:
            
            if levelSDA == .high, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_SDAH_SCLL
            }
            
            if levelSCL == .high {
                return .idle_SDAL_SCLH
            }
            
        case .started:
            
            if levelSDA == .high, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_SDAH_SCLL
            }
            
            if levelSCL == .low {
                return .started_SDAL_SCLL
            }
            
        case .started_SDAH_SCLH:
            
            if levelSDA == .low, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .low {
                return .started
            }
            
            if levelSCL == .low {
                return .started_SDAH_SCLL
            }
            
        case .started_SDAH_SCLL:
            
            if levelSDA == .low, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .low {
                return .started_SDAL_SCLL
            }
            
            if levelSCL == .high {
                return .started_SDAH_SCLH
            }
        
        case .started_SDAL_SCLH:
            
            if levelSDA == .high, levelSCL == .low {
                return .undef
            }
            
            if levelSDA == .high {
                return .idle_SDAH_SCLH
            }
            
            if levelSCL == .low {
                return .started_SDAL_SCLL
            }
        
        case .started_SDAL_SCLL:
            
            if levelSDA == .high, levelSCL == .high {
                return .undef
            }
            
            if levelSDA == .high {
                return .started_SDAH_SCLL
            }
            
            if levelSCL == .high {
                return .started_SDAL_SCLH
            }
        }
        
        return currentMicroState
    }
}
