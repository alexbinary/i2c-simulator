
import SwiftUI



class RenderSceneLine {
    
    let initialLevel: LineLevel
    var transitions: [CGFloat] = []
    
//    private var pullers: Set<UUID> = []
    
    init(
        initialLevel: LineLevel
    ) {
        self.initialLevel = initialLevel
    }
    
    func addTransition(at x: CGFloat) {
        transitions.append(x)
        transitions.sort()
    }
    
//    func addPuller(_ id: UUID) {
//        
//        pullers.insert(id)
//        updateLevel()
//    }
//    
//    func removePuller(_ id: UUID) {
//        
//        pullers.remove(id)
//        updateLevel()
//    }
//    
//    private func updateLevel() {
//        
//        currentLevel = pullers.count == 0 ? .high : .low
//    }
}



class RenderScene {
    
    
    let lineSCL = RenderSceneLine(initialLevel: .high)
    let lineSDA = RenderSceneLine(initialLevel: .high)
    
    var currentX: CGFloat = 0
    
    
    init() {
        self.run()
    }
    
    
    func advanceX(by step: CGFloat) {
        
        if (step < 0) { fatalError("X must always go forward") }
        
        self.currentX += step
    }
    
    
    func advanceX(to x: CGFloat) {
        
        if (x < self.currentX) { fatalError("X must always go forward") }
        
        self.currentX = x
    }
    
    
    func run() {
        
        advanceX(by: 100)
        
        //        i2c_start()
        //
        //        i2c_sendBit(.zero)
        //        i2c_sendBit(.one)
        //        i2c_ack()
        //
        //        i2c_start()
        //
        //        i2c_sendBit(.zero)
        //        i2c_sendBit(.one)
        //        i2c_nack()
        //
        //        i2c_stop()
        
        lineSDA.addTransition(at: 300)
        lineSDA.addTransition(at: 200)
    }
    
    
    //    func i2c_pullSDALow() {
    //
    //        lineSDA.addPuller(self.pullerId)
    //        transition(lineSDA, to: lineSDA.currentLevel)
    //    }
    //
    //    func i2c_pullSCLLow() {
    //
    //        lineSCL.addPuller(self.pullerId)
    //        transition(lineSCL, to: lineSCL.currentLevel)
    //    }
    //
    //    func i2c_releaseSDA() {
    //
    //        lineSDA.removePuller(self.pullerId)
    //        transition(lineSDA, to: lineSDA.currentLevel)
    //    }
    //
    //    func i2c_releaseSCL() {
    //
    //        lineSCL.removePuller(self.pullerId)
    //        transition(lineSCL, to: lineSCL.currentLevel)
    //    }
    //
    //    func i2c_SDAIsLow() -> Bool {
    //
    //        return lineSDA.currentLevel == .low
    //    }
    //
    //    func i2c_SDAIsHigh() -> Bool {
    //
    //        return lineSDA.currentLevel == .high
    //    }
    //
    //    func i2c_SCLIsLow() -> Bool {
    //
    //        return lineSCL.currentLevel == .low
    //    }
    //
    //    func i2c_SCLIsHigh() -> Bool {
    //
    //        return lineSCL.currentLevel == .high
    //    }
    //
    //
    //    func i2c_start() {
    //
    //        if i2c_SDAIsLow() {
    //
    //            i2c_pullSCLLow()
    //            advanceX(by: xStepDefaultSetup)
    //
    //            i2c_releaseSDA()
    //            advanceX(by: xStepDefaultSetup)
    //        }
    //
    //        i2c_releaseSCL()
    //        advanceX(by: xStepDefaultSetup)
    //
    //        i2c_pullSDALow()
    //        advanceX(by: xStepDefaultSetup)
    //    }
    //
    //
    //    func i2c_stop() {
    //
    //        i2c_pullSCLLow()
    //        advanceX(by: xStepDefaultSetup)
    //
    //        i2c_pullSDALow()
    //        advanceX(by: xStepDefaultSetup)
    //
    //        i2c_releaseSCL()
    //        advanceX(by: xStepDefaultSetup)
    //
    //        i2c_releaseSDA()
    //        advanceX(by: xStepDefaultSetup)
    //    }
    //
    //
    //    func i2c_sendBit(_ bit: Bit) {
    //
    //        if i2c_SCLIsHigh() {
    //
    //            i2c_pullSCLLow()
    //            advanceX(by: xStepDefaultSetup)
    //        }
    //
    //        if bit == .zero {
    //            i2c_pullSDALow()
    //        } else {
    //            i2c_releaseSDA()
    //        }
    //        advanceX(by: xStepDefaultSetup)
    //
    //        i2c_releaseSCL()
    //        advanceX(by: xStepBitClockHigh)
    //
    //        i2c_pullSCLLow()
    //        advanceX(by: xStepDefaultSetup)
    //    }
    //
    //
    //    func i2c_ack() {
    //
    //        i2c_sendBit(.zero)
    //    }
    //
    //
    //    func i2c_nack() {
    //
    //        i2c_sendBit(.one)
    //    }
}
