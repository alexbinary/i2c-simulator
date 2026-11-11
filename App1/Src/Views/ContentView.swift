
import SwiftUI



struct ContentView: View {
    
    
    @State private var viewportTranslation: CGFloat = 0
    @State private var viewportScale: CGFloat = 1
    
    @State private var viewportTranslationOnLastMouseDown: CGFloat? = nil
    
    @State private var screenMouse: CGPoint = .zero
    @State private var screenMouseOnLastDown: CGPoint = .zero
    
    
    private let zoomScrollCoeff: CGFloat = 0.001
    private let zoomPinchCoeff: CGFloat = 0.5
    
    
    var worldMouse: CGPoint {
        
        let inverseTransform: CGAffineTransform =
            .identity
            .concatenating(.init(translationX: -viewportTranslation, y: 0))
            .concatenating(.init(scaleX: 1/viewportScale, y: 1))
        
        return screenMouse.applying(inverseTransform)
    }
    
    
    var body: some View {

        ZStack {
            
            Canvas { context, canvasSize in
                
                context.scaleBy(x: 1, y: -1)
                context.translateBy(x: 0, y: -canvasSize.height)
                
                let renderer = Renderer(
                    context: context,
                    canvasSize: canvasSize,
                    viewportTranslation: viewportTranslation,
                    viewportScale: viewportScale
                )
                renderer.render()
            }
            
            MouseEventsArea(
                onMouseMove: { point in
                    moveMouse(toNewScreenPosition: point)
                },
                onMouseDown: { point in
                    screenMouseOnLastDown = screenMouse
                    viewportTranslationOnLastMouseDown = viewportTranslation
                },
                onMouseDrag: { point in
                    moveMouse(toNewScreenPosition: point, dragging: true)
                },
                onScroll: { dx, dy, modifiers, phase, momentumPhase in
                    panViewport(by: dx)
                    zoomViewport(by: dy*zoomScrollCoeff)
                },
                onPinch: { delta, point in
                    zoomViewport(by: delta*zoomPinchCoeff)
                }
            )
        }
        .frame(minWidth: 1600, minHeight: 800)
    }
    
    
    func moveMouse(toNewScreenPosition sp: CGPoint, dragging: Bool = false) {
        
        screenMouse = sp
        
        if dragging {
            
            if let base = viewportTranslationOnLastMouseDown {
                
                viewportTranslation = base + screenMouse.x - screenMouseOnLastDown.x
            }
        }
    }
    
    
    func panViewport(by dx: CGFloat) {
        
        viewportTranslation += dx
    }
    
    
    func panViewport(toHaveWorldPoint wp: CGPoint, appearOnScreenAt sp: CGPoint) {
        
        let s = viewportScale
        
        viewportTranslation = sp.x - s*wp.x
    }
    
    
    func zoomViewport(by delta: CGFloat) {
        
        let (wp, sp) = (worldMouse, screenMouse)
        viewportScale *= (1 + delta)
        panViewport(toHaveWorldPoint: wp, appearOnScreenAt: sp)
    }
}

#Preview {
    ContentView()
}
