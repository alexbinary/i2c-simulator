
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

    var busFSM = I2CBusFSM()
    
    
    func initCompute(x: CGFloat, levelSCL: LineLevel, levelSDA: LineLevel) {

        busFSM.reset(levelSCL: levelSCL, levelSDA: levelSDA)
    }
    
    
    func updateCompute(x: CGFloat, changedLine: I2CBusLineEnum?) -> I2CControllerLineAction? {
        
        if let line = changedLine {
            busFSM.update(changedLine: line)
        }

        return _updateCompute(x: x)
    }


    func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {
        
        return nil
    }
}
