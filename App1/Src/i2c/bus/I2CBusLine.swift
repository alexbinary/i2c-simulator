
import SwiftUI



class I2CBusLine {
    
    enum Identity { case SCL, SDA }

    let identity: Identity
    var currentLevel: I2CBusLineLevel = .high
    
    var isLow: Bool { return currentLevel == .low }
    var isHigh: Bool { return currentLevel == .high }
    
    var pullers: Set<UUID> = []
    var capturedLevels: [(x: CGFloat, level :I2CBusLineLevel)] = []


    init(_ identity: Identity) {
        
        self.identity = identity
    }


    func reset() {

        currentLevel = .high
        pullers = []
        capturedLevels = []
    }
    
    
    func addPuller(_ controller: I2CController) {
        
        pullers.insert(controller.id)
        updateLevel()
    }
    
    func removePuller(_ controller: I2CController) {
        
        pullers.remove(controller.id)
        updateLevel()
    }
    
    
    func updateLevel() {
        
        currentLevel = pullers.count == 0 ? .high : .low
    }
    
    
    func captureLevel(at x: CGFloat) {
        
        capturedLevels.append((x: x, level: currentLevel))
    }
}
