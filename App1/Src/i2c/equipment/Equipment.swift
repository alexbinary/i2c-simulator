
import SwiftUI



class Equipment {
    
    let id = UUID()
    var i2cController: I2CController?
    
    func reset(x: CGFloat) {
        i2cController?.reset(x: x)
    }
    
    func update(x: CGFloat) {
        i2cController?.update(x: x)
    }
}
