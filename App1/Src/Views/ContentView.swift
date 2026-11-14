
import SwiftUI



struct ContentView: View {
    
    
    @State private var scene = RenderScene()
    @State private var canvasSize: CGSize = .zero
    
    @State private var viewportTranslation: CGFloat = 0
    @State private var viewportScale: CGFloat = 1
    
    @State private var viewportTranslationOnLastMouseDown: CGFloat? = nil
    
    @State private var screenMouse: CGPoint = .zero
    @State private var screenMouseOnLastDown: CGPoint = .zero
    
    @State private var mouseHoverLocation: CGPoint? = nil
    
    
    private let zoomScrollCoeff: CGFloat = 0.001
    private let zoomPinchCoeff: CGFloat = 0.5

    private var worldMouse: CGPoint { CGPoint(x: (screenMouse.x - viewportTranslation)/viewportScale, y: canvasSize.height - screenMouse.y) }


    var body: some View {

        ZStack(alignment: .bottomLeading) {
            
            Canvas { context, canvasSize in
                
                context.scaleBy(x: 1, y: -1)
                context.translateBy(x: 0, y: -canvasSize.height)
                
                let renderer = Renderer(
                    context: context,
                    canvasSize: canvasSize,
                    viewportTranslation: viewportTranslation,
                    viewportScale: viewportScale,
                    screenMouseX: mouseHoverLocation != nil ? screenMouse.x : nil
                )
                renderer.render(scene)
            }
            .background(GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size, initial: true) { _, newSize in
                    self.canvasSize = newSize
                }
            })
            
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

            if let location = mouseHoverLocation {
                Text("x\(Int(worldMouse.x))")
                    .offset(x: location.x, y: location.y - canvasSize.height)
                    .offset(x: 12, y: -12)
            }
        }
        .frame(minWidth: 1600, minHeight: 800)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                mouseHoverLocation = location
            case .ended:
                mouseHoverLocation = nil
            }
        }
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
