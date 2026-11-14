
import SwiftUI



class I2CPerturbatorController: I2CController {
    
    
    override func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {

//        if x > 410 && x < 420 {
//            return .pullSDA
//        }
        return .releaseSDA
    }
}
