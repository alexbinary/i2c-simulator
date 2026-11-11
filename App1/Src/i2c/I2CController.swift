
import SwiftUI



class I2CController {
    
    
    var bus: I2CBus! = nil
    
    let pullerId = UUID()
    
    
    init(
        
    ) {
        
    }
    
    
    func connect(to bus: I2CBus) {
        
        self.bus = bus
    }
    
    
    func pullSDALow() {
        
        bus.pullSDALow(self.pullerId)
    }
    
    func pullSCLLow() {
        
        bus.pullSCLLow(self.pullerId)
    }
    
    func releaseSDA() {
        
        bus.releaseSDA(self.pullerId)
    }
    
    func releaseSCL() {
        
        bus.releaseSCL(self.pullerId)
    }
    
    func SDAIsLow() -> Bool {
        
        return bus.SDAIsLow()
    }
    
    func SDAIsHigh() -> Bool {
        
        return bus.SDAIsHigh()
    }
    
    func SCLIsLow() -> Bool {
        
        return bus.SCLIsLow()
    }
    
    func SCLIsHigh() -> Bool {
        
        return bus.SCLIsHigh()
    }
}
