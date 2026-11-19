
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
    
    
    func setPullers(_ controllers: [I2CController]) {
        
        pullers = Set(controllers.map { $0.id })
        
        currentLevel = pullers.count == 0 ? .high : .low
    }
    
    
    func captureLevel(at x: CGFloat) {
        
        capturedLevels.append((x: x, level: currentLevel))
    }
}
