
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

    var pullingSDA = false
    var pullingSCL = false
    
    
    func initCompute(x: CGFloat, levelSCL: LineLevel, levelSDA: LineLevel) {

        busFSM.reset(levelSCL: levelSCL, levelSDA: levelSDA)
    }
    
    
    func updateCompute(x: CGFloat, changedLine: I2CBusLineEnum?) -> I2CControllerLineAction? {
        
        if let line = changedLine {
            busFSM.update(changedLine: line)
        }

        let action = _updateCompute(x: x)
        updatePullStatus(from: action)
        return action
    }


    func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {
        
        return nil
    }


    private func updatePullStatus(from action: I2CControllerLineAction?) {

        if action.type == .pull, action.target == .SDA {
            pullingSDA = true
        }
        if action.type == .release, action.target == .SDA {
            pullingSDA = false
        }
        if action.type == .pull, action.target == .SCL {
            pullingSCL = true
        }
        if action.type == .release, action.target == .SCL {
            pullingSCL = false
        }
    }
}
