
import SwiftUI



struct LineRenderParams {
    
    let yLow: CGFloat
    let yHigh: CGFloat
    
    func y(for level: LineLevel) -> CGFloat {
        switch level {
        case .high: return yHigh
        case .low: return yLow
        }
    }
}



class RenderLine {
    
    let sceneLine: RenderSceneLine
    let slot: Int
    let color: Color
    let lineWidth: CGFloat
    
    var currentLevel: LineLevel
    var path: Path
    
    init(
        sceneLine: RenderSceneLine,
        slot: Int,
        color: Color,
        lineWidth: CGFloat
    ) {
        self.sceneLine = sceneLine
        self.slot = slot
        self.color = color
        self.lineWidth = lineWidth
        
        self.currentLevel = sceneLine.initialLevel
        self.path = Path()
    }
}



class Renderer {
    
    
    var context: GraphicsContext
    let canvasSize: CGSize
    let viewportTranslation: CGFloat
    let viewportScale: CGFloat
    
    let margin: CGFloat = 24
    
    
    init(
        context: GraphicsContext,
        canvasSize: CGSize,
        viewportTranslation: CGFloat,
        viewportScale: CGFloat
    ) {
        self.context = context
        self.canvasSize = canvasSize
        self.viewportTranslation = viewportTranslation
        self.viewportScale = viewportScale
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
    
    
    func move(_ line: RenderLine, toY y: CGFloat, at x: CGFloat) {
        
        let sx = toScreen(x)
        
        if let currentPoint = line.path.currentPoint, currentPoint.x < sx {
            line.path.addLine(to: CGPoint(x: sx, y: currentPoint.y))
        }
        
        line.path.addLine(to: CGPoint(x: sx, y: y))
    }
    
    
    func bring(_ line: RenderLine, to level: LineLevel, at x: CGFloat) {
        
        let params = params(forLineSlot: line.slot)
        let y = params.y(for: level)
        
        move(line, toY: y, at: x)
        line.currentLevel = level
    }
    
    
    func transition(_ line: RenderLine, at x: CGFloat) {
        
        bring(line, to: line.currentLevel.opposite, at: x)
    }
    
    
    func render(_ scene: RenderScene) {
        
        let lineWidth: CGFloat = 2
        
        let renderLineSCL = RenderLine(sceneLine: scene.lineSCL, slot: 0, color: .orange, lineWidth: lineWidth)
        let renderLineSDA = RenderLine(sceneLine: scene.lineSDA, slot: 1, color: .white, lineWidth: lineWidth)
        
        let renderLines: [RenderLine] = [renderLineSCL, renderLineSDA]
        
        let screenMinX: CGFloat = 0
        let screenMaxX: CGFloat = canvasSize.width
        
        let worldMinX: CGFloat = toWorld(screenMinX)
        let worldMaxX: CGFloat = toWorld(screenMaxX)
        
        for line in renderLines {
            
            var currentX = margin
            
            let params = params(forLineSlot: line.slot)
            line.path.move(to: CGPoint(x: toScreen(min(currentX, worldMinX)), y: params.y(for: line.currentLevel)))
            
            for x in line.sceneLine.transitions {
                self.transition(line, at: x)
                currentX = x
            }
            
            line.path.addLine(to: CGPoint(x: toScreen(max(currentX, worldMaxX)), y: params.y(for: line.currentLevel)))
            context.stroke(line.path, with: .color(line.color), lineWidth: line.lineWidth)
        }
    }
}

