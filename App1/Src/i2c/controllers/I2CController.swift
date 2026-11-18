
import SwiftUI



enum I2CControllerLineActionEnum {

    case pull
    case release
}

struct I2CControllerLineAction {

    let type: I2CControllerLineActionEnum
    let target: I2CBusLineEnum

    static let pullSDA = I2CControllerLineAction(type: .pull, target: .SDA)
    static let pullSCL = I2CControllerLineAction(type: .pull, target: .SCL)
    static let releaseSDA = I2CControllerLineAction(type: .release, target: .SDA)
    static let releaseSCL = I2CControllerLineAction(type: .release, target: .SCL)
}



class I2CController {
    
    
    let id = UUID()

    var bus: I2CBus!

    var pullingSDA = false
    var pullingSCL = false
    
    
    func connect(to bus: I2CBus) {
        
        self.bus = bus
    }
    
    
    func initState(x: CGFloat) {

    }
    
    
    func updateBusControl(after event: I2CBusEvent) {
        
    }
}
