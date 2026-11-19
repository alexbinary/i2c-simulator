
import SwiftUI



class I2CController {
    
    
    let id = UUID()
    var bus: I2CBus!

    var pullingSDA = false
    var pullingSCL = false
    
    func pulling(_ line: I2CBusLine.Identity) -> Bool {
        switch line {
        case .SCL: return pullingSCL
        case .SDA: return pullingSDA
        }
    }
    
    
    func connect(to bus: I2CBus) {
        
        self.bus = bus
    }
    
    
    func initState(x: CGFloat) {

    }
    
    
    func updateBusControl(x: CGFloat) {
        
    }
}
