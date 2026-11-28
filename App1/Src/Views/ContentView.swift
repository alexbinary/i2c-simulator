
import SwiftUI



struct ContentView: View {
    
    
    @FocusState var isFocused: Bool?
    
    @State var scene = RenderScene()
    @State var canvasSize: CGSize = .zero
    
    @State var viewportTranslation: CGFloat = 0
    @State var viewportScale: CGFloat = 1
    
    @State var viewportTranslationOnLastMouseDown: CGFloat? = nil
    
    @State var screenMouse: CGPoint = .zero
    @State var screenMouseOnLastDown: CGPoint = .zero
    
    @State var mouseHoverLocation: CGPoint? = nil
    
    
    let zoomScrollCoeff: CGFloat = 0.001
    let zoomPinchCoeff: CGFloat = 0.5

    var worldMouse: CGPoint { CGPoint(x: screenToWorld(screenMouse.x), y: canvasSize.height - screenMouse.y) }
    
    
    func worldToScreen(_ x: CGFloat) -> CGFloat {
        
        return viewportTranslation + (x)*viewportScale
    }
    
    func screenToWorld(_ x: CGFloat) -> CGFloat {
        
        return (x - viewportTranslation)/viewportScale
    }


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
            .focusable()
            .focused($isFocused, equals: true)
            .onKeyPress { press in
                if press.key == .rightArrow {
                    scene.activateNextMarkers()
                }
                if press.key == .leftArrow {
                    scene.activatePreviousMarkers()
                }
                if press.key == .escape {
                    scene.clearMarkers()
                }
                return .handled
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

            if let location = mouseHoverLocation {
                
                VStack(alignment: .leading) {
                    Text("x\(Int(worldMouse.x))")
                        .background(.black)
                }
                .offset(x: location.x, y: location.y - canvasSize.height)
                .offset(x: 12, y: -12)
            }
            
            let tips = scene.activeTextTips
            if !tips.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(tips) { tip in
                        HStack {
                            tip.color.frame(width: 6, height: 16)
                            Text(tip.text)
                                .background(.black)
                        }
                        .offset(x: worldToScreen(tip.x))
                    }
                }
                
                .offset(y: (mouseHoverLocation?.y ?? canvasSize.height*3/4) - canvasSize.height)
                .offset(y: -48)
            }
        }
        .frame(minWidth: 2000, minHeight: 800)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                mouseHoverLocation = location
            case .ended:
                mouseHoverLocation = nil
            }
        }
        .onAppear(perform: {
            isFocused = true
        })
    }
    
    
    func moveMouse(toNewScreenPosition sp: CGPoint, dragging: Bool = false) {
        
        screenMouse = sp
        
        scene.updateMouse(worldMouse: worldMouse.x)
        
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
