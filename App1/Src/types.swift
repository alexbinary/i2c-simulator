
import SwiftUI



struct LineParams {
    
    let yLow: CGFloat
    let yHigh: CGFloat
    
    func y(for level: LineLevel) -> CGFloat {
        switch level {
        case .high: return yHigh
        case .low: return yLow
        }
    }
}


enum LineLevel {
    
    case high, low
}


enum Bit {
    
    case zero, one
    
    var lineLevel: LineLevel {
        switch self {
        case .zero: return .low
        case .one: return .high
        }
    }
}


class Line {
    
    let slot: Int
    let color: Color
    var path: Path
    var currentLevel: LineLevel
    
    private var pullers: Set<UUID> = []
    
    init(
        slot: Int,
        color: Color
    ) {
        self.slot = slot
        self.color = color
        self.path = Path()
        self.currentLevel = .high
        updateLevel()
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
        currentLevel = pullers.count == 0 ? .high : .low
    }
}
