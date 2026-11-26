
import SwiftUI



protocol I2CBusConnectable: SimulationEntity {
    
    func connect(to bus: I2CBus)
}
