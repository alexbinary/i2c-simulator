
import SwiftUI



class I2CBusLine {
    
    var currentLevel: LineLevel = .high
    var currentX: CGFloat = 0
    
    private(set) var pullers: Set<UUID> = []
    private(set) var transitions: [CGFloat] = []
    
    
    var isHigh: Bool { currentLevel == .high }
    var isLow: Bool { currentLevel == .low }
    
    
    func advanceX(to x: CGFloat) {
        
        if (x < currentX) { fatalError("X must always go forward") }
        
        currentX = x
    }

    func addPuller(_ id: UUID) {

        pullers.insert(id)
        updateLevel()
    }

    func removePuller(_ id: UUID) {

        pullers.remove(id)
        updateLevel()
    }

    private func updateLevel() {

        let updatedLevel: LineLevel = pullers.count == 0 ? .high : .low
        if updatedLevel != currentLevel {
            
            currentLevel = updatedLevel
            registerTransition(at: currentX)
        }
    }
    
    private func registerTransition(at x: CGFloat) {
        
        transitions.append(x)
        transitions.sort()
    }
}
