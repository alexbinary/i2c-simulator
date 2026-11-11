
import SwiftUI



struct Vector {
    
    let dx: CGFloat
    let dy: CGFloat
    
    
    init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }
    
    init(from p1: CGPoint, to p2: CGPoint) {
        self.dx = p2.x - p1.x
        self.dy = p2.y - p1.y
    }
    
    
    static let zero = Vector(dx: 0, dy: 0)
    
    
    var lengthSq: CGFloat { dot(self, self) }
    var length: CGFloat { sqrt(lengthSq) }
    
    
    var point: CGPoint { .init(x: dx, y: dy) }
}



func +(_ v1: Vector, _ v2: Vector) -> Vector {
 
    return Vector(dx: v1.dx + v2.dx, dy: v1.dy + v2.dy)
}


func +=(_ v1: inout Vector, _ v2: Vector) {
 
    v1 = v1 + v2
}


func *(_ t: CGFloat, _ v: Vector) -> Vector {
    
    return Vector(dx: v.dx*t, dy: v.dy*t)
}


func +(_ p: CGPoint, _ v: Vector) -> CGPoint {
    
    return CGPoint(x: p.x + v.dx, y: p.y + v.dy)
}


func +(_ v: Vector, _ p: CGPoint) -> CGPoint {
    
    return p + v
}


func -(_ p1: CGPoint, _ p2: CGPoint) -> Vector {
    
    return Vector(dx: p1.x - p2.x, dy: p1.y - p2.y)
}


func dot(_ v1: Vector, _ v2: Vector) -> CGFloat {
    
    return v1.dx*v2.dx + v1.dy*v2.dy
}
