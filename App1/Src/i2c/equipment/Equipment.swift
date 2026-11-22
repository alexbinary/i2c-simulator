
import SwiftUI



class Equipment {
    
    let id = UUID()
    let i2cController: I2CController
    
    init(i2cController: I2CController) {
        self.i2cController = i2cController
    }
    
    func reset(x: CGFloat) {
        self.i2cController.reset(x: x)
    }
    
    func update(x: CGFloat) {
        self.i2cController.update(x: x)
    }
}
