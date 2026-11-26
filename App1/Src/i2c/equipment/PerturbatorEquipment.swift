
import SwiftUI



class PerturbatorEquipment: I2CController {
    
    
    override func update(x: CGFloat) {

        if x.truncatingRemainder(dividingBy: 6) == 0 {
            
            pullSCL()
        }
        if x.truncatingRemainder(dividingBy: 6) == 3 {
            
            releaseSCL()
        }
        
        if x > 1100 {
            releaseSCL()
        }
    }
}
