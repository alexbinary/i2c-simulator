
import SwiftUI



class Renderer {
    
    
    var context: GraphicsContext
    let canvasSize: CGSize
    let viewportTranslation: CGFloat
    let viewportScale: CGFloat
    
    let margin: CGFloat = 24
    
    let lineSCL = Line(slot: 0, color: .white)
    let lineSDA = Line(slot: 1, color: .yellow)
    
    var lines: [Line] { [lineSCL, lineSDA] }
    
    var currentX: CGFloat = 0
    
    let xStepDefaultSetup: CGFloat = 30
    let xStepBitClockHigh: CGFloat = 100
    
    let pullerId = UUID()
    
    
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
    
    
    func params(forLineSlot slot: Int) -> LineParams {
        
        let numberOfLines = 2
        
        let totalMargin = margin*CGFloat(numberOfLines+1)
        let lineHeight = (canvasSize.height - totalMargin)/CGFloat(numberOfLines)
        
        let bottom = margin + (lineHeight+margin)*CGFloat(slot)
        
        return LineParams(
            yLow: bottom,
            yHigh: bottom + lineHeight
        )
    }
    
    
    func transitionLine(_ line: Line, toY y: CGFloat, atX x: CGFloat) {
        
        if let currentPoint = line.path.currentPoint,
           currentPoint.x < x {
            line.path.addLine(to: CGPoint(x: x, y: currentPoint.y))
        }
        
        line.path.addLine(to: CGPoint(x: x, y: y))
    }
    
    
    func transition(_ line: Line, to level: LineLevel) {
        
        let params = params(forLineSlot: line.slot)
        transitionLine(line, toY: params.y(for: level), atX: self.currentX)
        line.currentLevel = level
    }
    
    
    func advanceX(by step: CGFloat) {
        
        self.currentX += step
    }
    
    
    func render() {
        
        var inverseTransform: CGAffineTransform =
            .identity
            .concatenating(.init(translationX: -viewportTranslation, y: 0))
            .concatenating(.init(scaleX: 1/viewportScale, y: 1))
        
        let worldVisibleBounds = CGRect(origin: .zero, size: canvasSize).applying(inverseTransform)
        
        context.translateBy(x: viewportTranslation, y: 0)
        context.scaleBy(x: viewportScale, y: 1)
        
        //
        
        self.currentX = margin
        
        for line in lines {
            let params = params(forLineSlot: line.slot)
            line.path.move(to: CGPoint(x: min(self.currentX, worldVisibleBounds.minX), y: params.y(for: line.currentLevel)))
        }
        
        advanceX(by: 100)
        
        i2c_start()
        
        i2c_sendBit(.zero)
        i2c_sendBit(.one)
        i2c_ack()
        
        i2c_start()
        
        i2c_sendBit(.zero)
        i2c_sendBit(.one)
        i2c_nack()
        
        i2c_stop()
        
        for line in lines {
            let params = params(forLineSlot: line.slot)
            line.path.addLine(to: CGPoint(x: max(self.currentX, worldVisibleBounds.maxX), y: params.y(for: line.currentLevel)))
            context.stroke(line.path, with: .color(line.color), lineWidth: 1)
        }
    }
    
    
    func i2c_pullSDALow() {
        
        lineSDA.addPuller(self.pullerId)
        transition(lineSDA, to: lineSDA.currentLevel)
    }
    
    func i2c_pullSCLLow() {
        
        lineSCL.addPuller(self.pullerId)
        transition(lineSCL, to: lineSCL.currentLevel)
    }
    
    func i2c_releaseSDA() {
        
        lineSDA.removePuller(self.pullerId)
        transition(lineSDA, to: lineSDA.currentLevel)
    }
    
    func i2c_releaseSCL() {
        
        lineSCL.removePuller(self.pullerId)
        transition(lineSCL, to: lineSCL.currentLevel)
    }
    
    func i2c_SDAIsLow() -> Bool {
        
        return lineSDA.currentLevel == .low
    }
    
    func i2c_SDAIsHigh() -> Bool {
        
        return lineSDA.currentLevel == .high
    }
    
    func i2c_SCLIsLow() -> Bool {
        
        return lineSCL.currentLevel == .low
    }
    
    func i2c_SCLIsHigh() -> Bool {
        
        return lineSCL.currentLevel == .high
    }
    
    
    func i2c_start() {
        
        if i2c_SDAIsLow() {
            
            i2c_pullSCLLow()
            advanceX(by: xStepDefaultSetup)
            
            i2c_releaseSDA()
            advanceX(by: xStepDefaultSetup)
        }
        
        i2c_releaseSCL()
        advanceX(by: xStepDefaultSetup)
        
        i2c_pullSDALow()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_stop() {
        
        i2c_pullSCLLow()
        advanceX(by: xStepDefaultSetup)
        
        i2c_pullSDALow()
        advanceX(by: xStepDefaultSetup)
        
        i2c_releaseSCL()
        advanceX(by: xStepDefaultSetup)
        
        i2c_releaseSDA()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_sendBit(_ bit: Bit) {
        
        if i2c_SCLIsHigh() {
            
            i2c_pullSCLLow()
            advanceX(by: xStepDefaultSetup)
        }
        
        if bit == .zero {
            i2c_pullSDALow()
        } else {
            i2c_releaseSDA()
        }
        advanceX(by: xStepDefaultSetup)
        
        i2c_releaseSCL()
        advanceX(by: xStepBitClockHigh)
        
        i2c_pullSCLLow()
        advanceX(by: xStepDefaultSetup)
    }
    
    
    func i2c_ack() {
        
        i2c_sendBit(.zero)
    }
    
    
    func i2c_nack() {
        
        i2c_sendBit(.one)
    }
}

