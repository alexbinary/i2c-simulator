
import SwiftUI



class I2CBus {
    
    let lineSCL = I2CBusLine()
    let lineSDA = I2CBusLine()
    
    func advanceX(to x: CGFloat) {
        
        lineSCL.advanceX(to: x)
        lineSDA.advanceX(to: x)
    }
    
    func pullSDALow(_ pullerId: UUID) {
        
        lineSDA.addPuller(pullerId)
    }
    
    func pullSCLLow(_ pullerId: UUID) {
        
        lineSCL.addPuller(pullerId)
    }
    
    func releaseSDA(_ pullerId: UUID) {
        
        lineSDA.removePuller(pullerId)
    }
    
    func releaseSCL(_ pullerId: UUID) {
        
        lineSCL.removePuller(pullerId)
    }
    
    func SDAIsLow() -> Bool {
        
        return lineSDA.isLow
    }
    
    func SDAIsHigh() -> Bool {
        
        return lineSDA.isHigh
    }
    
    func SCLIsLow() -> Bool {
        
        return lineSCL.isLow
    }
    
    func SCLIsHigh() -> Bool {
        
        return lineSCL.isHigh
    }
}
