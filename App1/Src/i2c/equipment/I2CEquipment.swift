
import SwiftUI



protocol I2CEquipment: SimulationEntity {
    
    func connect(to bus: I2CBus)
}
