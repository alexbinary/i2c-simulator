
import SwiftUI



struct ContentView: View {
    
    
    var body: some View {

        Canvas { context, canvasSize in
            
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: -canvasSize.height)
            
            let renderer = Renderer(
                context: context,
                canvasSize: canvasSize
            )
            renderer.render()
        }
        .frame(minWidth: 1600, minHeight: 800)
    }
}

#Preview {
    ContentView()
}
