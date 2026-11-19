
import SwiftUI



struct LineRenderParams {
    
    let yLow: CGFloat
    let yHigh: CGFloat
    
    func y(for level: I2CBusLineLevel) -> CGFloat {
        switch level {
        case .high: return yHigh
        case .low: return yLow
        }
    }
}


class RenderLine {
    
    let sceneLine: I2CBusLine
    let slot: Int
    let color: Color
    let lineWidth: CGFloat
    var path: Path
    
    init(
        sceneLine: I2CBusLine,
        slot: Int,
        color: Color,
        lineWidth: CGFloat
    ) {
        self.sceneLine = sceneLine
        self.slot = slot
        self.color = color
        self.lineWidth = lineWidth
        self.path = Path()
    }
}



class Renderer {
    
    
    private var context: GraphicsContext
    private let canvasSize: CGSize
    private let viewportTranslation: CGFloat
    private let viewportScale: CGFloat
    private let screenMouseX: CGFloat?
    
    private let margin: CGFloat = 24
    
    
    init(
        context: GraphicsContext,
        canvasSize: CGSize,
        viewportTranslation: CGFloat,
        viewportScale: CGFloat,
        screenMouseX: CGFloat?
    ) {
        self.context = context
        self.canvasSize = canvasSize
        self.viewportTranslation = viewportTranslation
        self.viewportScale = viewportScale
        self.screenMouseX = screenMouseX
    }
    
    
    func toScreen(_ x: CGFloat) -> CGFloat {
        
        return viewportTranslation + (x)*viewportScale
    }
    
    func toWorld(_ x: CGFloat) -> CGFloat {
        
        return (x - viewportTranslation)/viewportScale
    }
    
    
    func params(forLineSlot slot: Int) -> LineRenderParams {
        
        let numberOfLines = 2
        
        let totalMargin = margin*CGFloat(numberOfLines+1)
        let lineHeight = (canvasSize.height - totalMargin)/CGFloat(numberOfLines)
        
        let bottom = margin + (lineHeight+margin)*CGFloat(slot)
        
        return LineRenderParams(
            yLow: bottom,
            yHigh: bottom + lineHeight
        )
    }
    
    
    func set(_ line: RenderLine, toY y: CGFloat, at x: CGFloat) {
        
        let sx = toScreen(x)
        
        if let currentPoint = line.path.currentPoint, currentPoint.x < sx {
            line.path.addLine(to: CGPoint(x: sx, y: currentPoint.y))
        }
        
        line.path.addLine(to: CGPoint(x: sx, y: y))
    }
    
    
    func set(_ line: RenderLine, to level: I2CBusLineLevel, at x: CGFloat) {
        
        let params = params(forLineSlot: line.slot)
        let y = params.y(for: level)
        
        set(line, toY: y, at: x)
    }
    
    
    func render(_ scene: RenderScene) {
        
        let lineWidth: CGFloat = 2
        
        let renderLineSCL = RenderLine(sceneLine: scene.bus.lineSCL, slot: 0, color: .orange, lineWidth: lineWidth)
        let renderLineSDA = RenderLine(sceneLine: scene.bus.lineSDA, slot: 1, color: .white, lineWidth: lineWidth)
        let renderLines: [RenderLine] = [renderLineSCL, renderLineSDA]
        
        let screenMinX: CGFloat = 0
        let screenMaxX: CGFloat = canvasSize.width
        
        let worldMinX: CGFloat = toWorld(screenMinX)
        let worldMaxX: CGFloat = toWorld(screenMaxX)
        
        for line in renderLines {
            
            let params = params(forLineSlot: line.slot)
            
            let capturedLevelsSorted = line.sceneLine.capturedLevels.sorted(by: { $0.x < $1.x })
            
            var currentX: CGFloat = capturedLevelsSorted.first?.x ?? margin
            var currentLineLevel: I2CBusLineLevel = capturedLevelsSorted.first?.level ?? .high
            
            line.path.move(to: CGPoint(x: toScreen(min(currentX, worldMinX)), y: params.y(for: currentLineLevel)))
                
            for (x, level) in capturedLevelsSorted {
                currentX = x
                line.path.addLine(to: CGPoint(x: toScreen(currentX), y: params.y(for: currentLineLevel)))
                currentLineLevel = level
                line.path.addLine(to: CGPoint(x: toScreen(currentX), y: params.y(for: currentLineLevel)))
            }
            
            line.path.addLine(to: CGPoint(x: toScreen(max(currentX, worldMaxX)), y: params.y(for: currentLineLevel)))
            context.stroke(line.path, with: .color(line.color), lineWidth: line.lineWidth)
        }
        
        if let x = screenMouseX {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: canvasSize.height))
            context.stroke(path, with: .color(.white), lineWidth: 1)
        }
    }
}

