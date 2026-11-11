
import SwiftUI



class I2CBusLine {
    
    var currentLevel: LineLevel = .high
    
    private(set) var pullers: Set<UUID> = []
    private(set) var transitions: [CGFloat] = []
    
    
    func addPuller(_ controller: I2CController) {

        pullers.insert(controller.id)
    }

    func removePuller(_ controller: I2CController) {

        pullers.remove(controller.id)
    }

    func updateLevel() -> Bool {

        let updatedLevel: LineLevel = pullers.count == 0 ? .high : .low
        if updatedLevel != currentLevel {
            
            currentLevel = updatedLevel
            return true
        }
        
        return false
    }
    
    func registerTransition(at x: CGFloat) {
        
        transitions.append(x)
        transitions.sort()
    }
}
