
import SwiftUI



class I2CPerturbatorController: I2CController {
    
    
    override func _updateCompute(x: CGFloat) -> I2CControllerLineAction? {

        if x > 110 && x < 120 {
            return .pullSDA
        }
        return .releaseSDA
    }
}
