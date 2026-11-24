
import SwiftUI



class I2CController: SimulationEntity {
    
    
    let id = UUID()
    var bus: I2CBus!
    
    var txFifo = Fifo(size: 256)
    var rxFifo = Fifo(size: 256)

    
    func connect(to bus: I2CBus) {
        
        self.bus = bus
    }
    
    
    func pull(_ line: I2CBusLine.Identity) {
        
        bus.line(line).addPuller(self)
    }
        
    func release(_ line: I2CBusLine.Identity) {
        
        bus.line(line).removePuller(self)
    }
    
    func pullSDA() {
        
        pull(.SDA)
    }
    
    func pullSCL() {
        
        pull(.SCL)
    }
    
    func releaseSDA() {
        
        release(.SDA)
    }
    
    func releaseSCL() {
        
        release(.SCL)
    }
    
    
    func detectedSymbol(analysingTransitionFrom lineLevelsBefore: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel), to lineLevelsAfter: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel)) -> I2CBusSymbol? {
        
        if lineLevelsBefore == (SCL: .high, SDA: .high) && lineLevelsAfter == (SCL: .high, SDA: .low) {
            return .start
        }
        
        if lineLevelsBefore == (SCL: .high, SDA: .low) && lineLevelsAfter == (SCL: .high, SDA: .high) {
            return .stop
        }
        
        if lineLevelsBefore.SCL == .high && lineLevelsAfter.SCL == .low {
            return .clockFall
        }
        
        if lineLevelsBefore.SCL == .low && lineLevelsAfter.SCL == .high {
            return .clockRise
        }
        
        return nil
    }
    
    
    func reset(x: CGFloat) {
        
    }
    
    func update(x: CGFloat) {
        
    }
}
