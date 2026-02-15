import SwiftUI
import PencilKit

enum ExcelMode: CaseIterable {
    case grammar
    case calligraphy
    case flashcards
    
    var title: String {
        switch self {
        case .grammar: return "Grammar"
        case .calligraphy: return "Calligraphy"
        case .flashcards: return "Flashcard"
        }
    }
    
    var icon: String {
        switch self {
        case .grammar: return "text.book.closed.fill"
        case .calligraphy: return "paintbrush.pointed.fill"
        case .flashcards: return "rectangle.stack.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .grammar: return AppTheme.forestGreenLight
        case .calligraphy: return AppTheme.forestGreen
        case .flashcards: return AppTheme.gold
        }
    }
    
    static func random() -> ExcelMode {
        ExcelMode.allCases.randomElement() ?? .flashcards
    }
}

struct ExcelModeView: View {
    @EnvironmentObject var store: FlashcardStore
    @ObservedObject var betaStore = CharacterBetaStore.shared
    
    @State private var currentMode: ExcelMode = .random()
    @State private var questionNumber = 1
    @State private var studyQueue: [Flashcard] = []
    @State private var currentCardIndex = 0
    
    var currentCard: Flashcard? {
        guard !studyQueue.isEmpty, currentCardIndex < studyQueue.count else { return nil }
        return studyQueue[currentCardIndex]
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Mode indicator header
                HStack {
                    Text("Question \(questionNumber)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: currentMode.icon)
                            .foregroundColor(currentMode.color)
                        Text(currentMode.title)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(currentMode.color)
                    }
                }
                .padding()
                .background(AppTheme.backgroundCard)
                
                // Current mode content
                if studyQueue.isEmpty {
                    ContentUnavailableView(
                        "No Cards Available",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Select a deck to start Excel mode")
                    )
                } else {
                    switch currentMode {
                    case .grammar:
                        ExcelGrammarStep(onComplete: advanceToNext)
                    case .calligraphy:
                        if let card = currentCard {
                            ExcelCalligraphyStep(card: card, onComplete: advanceToNext)
                        }
                    case .flashcards:
                        if let card = currentCard {
                            ExcelFlashcardStep(card: card, onComplete: advanceToNext)
                        }
                    }
                }
            }
        }
        .navigationTitle("Excel Mode")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStudyQueue()
        }
    }
    
    private func loadStudyQueue() {
        // Use cards from ALL active decks, not just selected deck
        studyQueue = store.getActiveDecksStudyQueue()
        currentCardIndex = 0
        questionNumber = 1
        currentMode = .random()
    }
    
    private func advanceToNext() {
        questionNumber += 1
        currentCardIndex = (currentCardIndex + 1) % max(1, studyQueue.count)
        currentMode = .random()
    }
}

// MARK: - Excel Grammar Step
struct ExcelGrammarStep: View {
    @EnvironmentObject var store: FlashcardStore
    let onComplete: () -> Void
    
    var body: some View {
        GrammarPracticeView()
            .overlay(alignment: .bottom) {
                Button(action: onComplete) {
                    Text("Next Question")
                        .font(AppTheme.Typography.headline)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(AppTheme.forestGreen)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Radius.md)
                }
                .padding(.bottom, 20)
            }
    }
}

// MARK: - Excel Calligraphy Step
struct ExcelCalligraphyStep: View {
    let card: Flashcard
    let onComplete: () -> Void
    @ObservedObject var betaStore = CharacterBetaStore.shared
    
    @State private var canvasView = PKCanvasView()
    @State private var hasChecked = false
    @State private var strokeCount = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        let canvasSize: CGFloat = isIPad ? 350 : min(UIScreen.main.bounds.width - 80, 280)
        
        VStack(spacing: 16) {
            Spacer()
            
            Text("Draw the character for:")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
            
            Text(card.definition)
                .font(AppTheme.Typography.title)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            ZStack {
                ChineseCharacterGrid(size: canvasSize)
                
                ExcelDrawingCanvas(canvasView: $canvasView, onStrokeChanged: {
                    strokeCount = canvasView.drawing.strokes.count
                })
                    .frame(width: canvasSize, height: canvasSize)
                    .clipShape(Rectangle())
            }
            .frame(width: canvasSize, height: canvasSize)
            
            if hasChecked {
                VStack(spacing: 8) {
                    Text("Correct character:")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(card.term)
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(AppTheme.forestGreen)
                }
                
                HStack(spacing: 30) {
                    Button(action: {
                        betaStore.recordFailure(for: card.term)
                        onComplete()
                    }) {
                        VStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 40))
                            Text("Wrong")
                                .font(AppTheme.Typography.caption)
                        }
                        .foregroundColor(AppTheme.error)
                    }
                    
                    Button(action: {
                        betaStore.recordSuccess(for: card.term)
                        onComplete()
                    }) {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                            Text("Correct")
                                .font(AppTheme.Typography.caption)
                        }
                        .foregroundColor(AppTheme.forestGreen)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    Button(action: { canvasView.drawing = PKDrawing() }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.error)
                }
                
                Button(action: { hasChecked = true }) {
                    Text("Show Answer")
                        .font(AppTheme.Typography.headline)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(strokeCount == 0 ? AppTheme.stone : AppTheme.forestGreen)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Radius.md)
                }
                .disabled(strokeCount == 0)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Excel Flashcard Step
struct ExcelFlashcardStep: View {
    let card: Flashcard
    let onComplete: () -> Void
    
    @State private var isFlipped = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .fill(AppTheme.backgroundCard)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 5)
                
                VStack(spacing: 16) {
                    if isFlipped {
                        Text(card.definition)
                            .font(AppTheme.Typography.title)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Text(card.term)
                            .font(.system(size: 80, weight: .medium))
                            .foregroundColor(AppTheme.forestGreen)
                    } else {
                        Text(card.term)
                            .font(.system(size: 120, weight: .medium))
                            .foregroundColor(AppTheme.gold)
                        
                        Text("Tap to flip")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: 320, maxHeight: 380)
            .onTapGesture {
                withAnimation(.spring()) {
                    isFlipped.toggle()
                }
            }
            
            Spacer()
            
            if isFlipped {
                Button(action: onComplete) {
                    Text("Next Question")
                        .font(AppTheme.Typography.headline)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(AppTheme.forestGreen)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Radius.md)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Excel Drawing Canvas
class WhiteInkCanvasView: PKCanvasView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWhiteInk()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWhiteInk()
    }
    
    private func setupWhiteInk() {
        // Use marker instead of pen - marker doesn't adapt colors
        let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        self.tool = PKInkingTool(ink: ink, width: 8)
        self.drawingPolicy = .anyInput
        self.backgroundColor = .clear
        self.isOpaque = false
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        self.tool = PKInkingTool(ink: ink, width: 8)
    }
}

struct ExcelDrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var onStrokeChanged: () -> Void = {}
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = WhiteInkCanvasView()
        canvas.delegate = context.coordinator
        // Copy reference for clearing
        DispatchQueue.main.async {
            self.canvasView = canvas
        }
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Force white marker ink
        let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        uiView.tool = PKInkingTool(ink: ink, width: 8)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onStrokeChanged: onStrokeChanged)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onStrokeChanged: () -> Void
        
        init(onStrokeChanged: @escaping () -> Void) {
            self.onStrokeChanged = onStrokeChanged
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
            canvasView.tool = PKInkingTool(ink: ink, width: 8)
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onStrokeChanged()
        }
    }
}

#Preview {
    NavigationStack {
        ExcelModeView()
            .environmentObject(FlashcardStore())
    }
}
