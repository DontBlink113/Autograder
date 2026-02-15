import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var strokeColor: UIColor
    let onDrawingChanged: () -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        // Use marker - it doesn't adapt colors like pen does
        let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        canvasView.tool = PKInkingTool(ink: ink, width: 8)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        uiView.tool = PKInkingTool(ink: ink, width: 8)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: () -> Void
        
        init(onDrawingChanged: @escaping () -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged()
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
            canvasView.tool = PKInkingTool(ink: ink, width: 8)
        }
    }
}

struct SampledPointsOverlay: View {
    let pointGroups: [[CGPoint]]
    
    private let pointColors: [Color] = [
        .red,
        .orange,
        .pink,
        .cyan
    ]
    
    var body: some View {
        Canvas { context, size in
            for (groupIndex, points) in pointGroups.enumerated() {
                let color = pointColors[groupIndex % pointColors.count]
                
                for point in points {
                    let rect = CGRect(
                        x: point.x - 3,
                        y: point.y - 3,
                        width: 6,
                        height: 6
                    )
                    context.fill(Circle().path(in: rect), with: .color(color))
                }
            }
        }
    }
}

struct ChineseCharacterGrid: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))  // Dark background for white ink
                .frame(width: size, height: size)
            
            Rectangle()
                .strokeBorder(Color.gray.opacity(0.6), lineWidth: 2)
                .frame(width: size, height: size)
            
            Path { path in
                path.move(to: CGPoint(x: size / 2, y: 0))
                path.addLine(to: CGPoint(x: size / 2, y: size))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            .foregroundColor(.gray.opacity(0.5))
            .frame(width: size, height: size)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: size / 2))
                path.addLine(to: CGPoint(x: size, y: size / 2))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            .foregroundColor(.gray.opacity(0.5))
            .frame(width: size, height: size)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: size))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            .foregroundColor(.gray.opacity(0.3))
            .frame(width: size, height: size)
            
            Path { path in
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            .foregroundColor(.gray.opacity(0.3))
            .frame(width: size, height: size)
        }
    }
}
