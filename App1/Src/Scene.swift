
import SwiftUI



class RenderSceneLine {
    
    let initialLevel: LineLevel
    var transitions: [CGFloat] = []
    
    init(
        initialLevel: LineLevel
    ) {
        self.initialLevel = initialLevel
    }
    
    func addTransition(at x: CGFloat) {
        transitions.append(x)
        transitions.sort()
    }
}



class RenderScene {
    
    
    let lines: [RenderSceneLine]
    
    
    init(
        lines: [RenderSceneLine]
    ) {
        self.lines = lines
    }
}
