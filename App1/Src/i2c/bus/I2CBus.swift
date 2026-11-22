
import SwiftUI



class I2CBus {
    
    
    let lineSCL = I2CBusLine(.SCL)
    let lineSDA = I2CBusLine(.SDA)
    func line(_ identity: I2CBusLine.Identity) -> I2CBusLine {
        switch identity {
        case .SCL: return lineSCL
        case .SDA: return lineSDA
        }
    }
    var currentLineLevels: (SCL: I2CBusLineLevel, SDA: I2CBusLineLevel) { (SCL: lineSCL.currentLevel, SDA: lineSDA.currentLevel) }


    func reset() {

        lineSCL.reset()
        lineSDA.reset()
    }
    
    
    func captureLineLevels(at x: CGFloat) {
        
        for line in [lineSCL, lineSDA] {
            line.captureLevel(at: x)
        }
    }
}
