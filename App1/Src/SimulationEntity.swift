
import SwiftUI



protocol SimulationEntity {

    func reset(x: CGFloat)
    func update(x: CGFloat)
    var markers: [SimulationMarker] { get }
}

struct SimulationMarker {
    
    let x: CGFloat
    let color: Color
    let label: String
}
