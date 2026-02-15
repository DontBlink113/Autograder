import SwiftUI
import PencilKit

// MARK: - Recognition Result
struct CharacterRecognition {
    var recognizedCharacter: String?
    var confidence: Float
    var isProcessing: Bool
    var autograderResponse: AutograderResponse?
    var strokeStatuses: [StrokeStatus]?
    
    static let empty = CharacterRecognition(recognizedCharacter: nil, confidence: 0, isProcessing: false, autograderResponse: nil, strokeStatuses: nil)
}

// MARK: - Data Structure for Character Strokes
struct CharacterStrokeData: Identifiable {
    let id = UUID()
    var boxIndex: Int
    var strokes: [PKStroke]
    
    var isEmpty: Bool {
        strokes.isEmpty
    }
}

// MARK: - Feedback Item
enum FeedbackType {
    case correct           // User wrote the correct character
    case wrong             // User wrote wrong character - show correct one
    case missing           // User omitted this character - show what should be there
    case extra             // User wrote extra character not needed
}

struct FeedbackItem: Identifiable {
    let id = UUID()
    let boxIndex: Int      // Which box this feedback is for
    let type: FeedbackType
    let userChar: String?  // What user wrote (nil if missing)
    let correctChar: String? // What should be there (nil if extra)
}

class GrammarCanvasData: ObservableObject {
    @Published var characterData: [Int: [PKStroke]] = [:]
    @Published var recognitionResults: [Int: CharacterRecognition] = [:]
    @Published var currentActiveBox: Int? = nil
    
    // Allowed characters for constrained recognition (set from the expected Chinese sentence)
    var allowedCharacters: String = ""
    
    private let confidenceThreshold: Float = 0.3
    private let sampler = StrokeSampler(pointsPerStroke: 50)
    
    func addStroke(_ stroke: PKStroke, toBox boxIndex: Int) {
        if characterData[boxIndex] == nil {
            characterData[boxIndex] = []
        }
        characterData[boxIndex]?.append(stroke)
        
        // If user moved to a new box, trigger OCR on the previous box
        if let previousBox = currentActiveBox, previousBox != boxIndex {
            triggerRecognition(forBox: previousBox)
        }
        
        // If user returns to a box that was already recognized, reset it
        if recognitionResults[boxIndex] != nil {
            recognitionResults[boxIndex] = .empty
        }
        
        currentActiveBox = boxIndex
    }
    
    func removeLastStroke(fromBox boxIndex: Int) {
        if characterData[boxIndex]?.isEmpty == false {
            characterData[boxIndex]?.removeLast()
        }
        if characterData[boxIndex]?.isEmpty == true {
            characterData.removeValue(forKey: boxIndex)
            recognitionResults.removeValue(forKey: boxIndex)
        } else {
            // Reset recognition if strokes changed
            recognitionResults[boxIndex] = .empty
        }
    }
    
    func syncStrokes(forBox boxIndex: Int, strokes: [PKStroke]) {
        if strokes.isEmpty {
            characterData.removeValue(forKey: boxIndex)
            recognitionResults.removeValue(forKey: boxIndex)
        } else {
            characterData[boxIndex] = strokes
            // Reset recognition if strokes changed
            if recognitionResults[boxIndex]?.recognizedCharacter != nil {
                recognitionResults[boxIndex] = .empty
            }
        }
    }
    
    func clearBox(_ boxIndex: Int) {
        characterData.removeValue(forKey: boxIndex)
        recognitionResults.removeValue(forKey: boxIndex)
    }
    
    func clearAll() {
        characterData.removeAll()
        recognitionResults.removeAll()
        currentActiveBox = nil
    }
    
    func getStrokes(forBox boxIndex: Int) -> [PKStroke] {
        return characterData[boxIndex] ?? []
    }
    
    var allStrokes: [PKStroke] {
        characterData.values.flatMap { $0 }
    }
    
    // MARK: - ML Kit Digital Ink Recognition
    func triggerRecognition(forBox boxIndex: Int) {
        guard let strokes = characterData[boxIndex], !strokes.isEmpty else { return }
        
        // Mark as processing
        recognitionResults[boxIndex] = CharacterRecognition(
            recognizedCharacter: nil,
            confidence: 0,
            isProcessing: true,
            autograderResponse: nil,
            strokeStatuses: nil
        )
        
        // Use HanziLookup API with constrained character set
        DigitalInkRecognizer.shared.recognize(strokes: strokes, allowedCharacters: allowedCharacters.isEmpty ? nil : allowedCharacters) { [weak self] (result: Result<String, Error>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let recognizedChar):
                    if !recognizedChar.isEmpty {
                        self.recognitionResults[boxIndex] = CharacterRecognition(
                            recognizedCharacter: recognizedChar,
                            confidence: 1.0,
                            isProcessing: false,
                            autograderResponse: nil,
                            strokeStatuses: nil
                        )
                        // Trigger autograder in parallel
                        self.triggerAutograder(forBox: boxIndex, character: recognizedChar, strokes: strokes)
                    } else {
                        self.recognitionResults[boxIndex] = CharacterRecognition(
                            recognizedCharacter: nil,
                            confidence: 0,
                            isProcessing: false,
                            autograderResponse: nil,
                            strokeStatuses: nil
                        )
                    }
                    
                case .failure(let error):
                    print("ML Kit recognition error: \(error)")
                    self.recognitionResults[boxIndex] = CharacterRecognition(
                        recognizedCharacter: nil,
                        confidence: 0,
                        isProcessing: false,
                        autograderResponse: nil,
                        strokeStatuses: nil
                    )
                }
            }
        }
    }
    
    // MARK: - Autograder API
    private func triggerAutograder(forBox boxIndex: Int, character: String, strokes: [PKStroke]) {
        // Convert strokes to CGPoints for API
        var strokePoints: [[CGPoint]] = []
        for stroke in strokes {
            let sampledPoints = sampler.samplePoints(from: stroke.path, startIndex: 0, endIndex: stroke.path.count - 1)
            let cgPoints = sampledPoints.map { $0.cgPoint }
            strokePoints.append(cgPoints)
        }
        
        AutograderAPI.shared.classifyStrokes(character: character, strokes: strokePoints) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    let statuses = AutograderAPI.getStrokeStatuses(from: response)
                    if var recognition = self.recognitionResults[boxIndex] {
                        recognition.autograderResponse = response
                        recognition.strokeStatuses = statuses
                        self.recognitionResults[boxIndex] = recognition
                    }
                case .failure(let error):
                    print("Autograder Error for box \(boxIndex): \(error)")
                }
            }
        }
    }
    
    // Trigger recognition for all boxes that haven't been processed yet
    func recognizeAllPending() {
        for boxIndex in characterData.keys {
            if recognitionResults[boxIndex]?.recognizedCharacter == nil &&
               recognitionResults[boxIndex]?.isProcessing != true {
                triggerRecognition(forBox: boxIndex)
            }
        }
    }
}

// MARK: - Grammar Practice View
struct GrammarPracticeView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var practiceStats = PracticeStats.shared
    @ObservedObject var betaStore = CharacterBetaStore.shared
    @StateObject private var canvasData = GrammarCanvasData()
    @State private var canvasView = PKCanvasView()
    @State private var isErasing = false
    @State private var previousStrokeCount = 0
    
    // Sentence from GPT
    @State private var englishSentence = ""
    @State private var chineseSentence = ""
    @State private var isLoadingSentence = true
    @State private var loadError: String? = nil
    @State private var hasChecked = false
    @State private var feedbackItems: [FeedbackItem] = []
    @State private var lastAnswerWasCorrect = true
    
    private let boxCount = 10
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        if isIPad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        let boxSize: CGFloat = 80
        let totalWidth = CGFloat(boxCount) * boxSize
        
        return VStack(spacing: 16) {
            // Stats header
            HStack {
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(practiceStats.currentStreak)", systemImage: "flame.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(practiceStats.currentStreak > 0 ? AppTheme.amber : AppTheme.stone)
                    
                    Label("\(practiceStats.questionsAnswered)", systemImage: "checkmark.circle")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal)
            
            // Prompt section
            VStack(spacing: 8) {
                Text("Translate to Chinese:")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                
                if isLoadingSentence {
                    ProgressView()
                        .padding()
                } else if let error = loadError {
                    VStack(spacing: 8) {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.error)
                        Button("Retry") {
                            loadNewSentence()
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.forestGreen)
                    }
                } else {
                    Text(englishSentence)
                        .font(AppTheme.Typography.title)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    if hasChecked {
                        Text(chineseSentence)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(AppTheme.forestGreen)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Recognized characters row
            HStack(spacing: 0) {
                ForEach(0..<boxCount, id: \.self) { index in
                    RecognitionLabel(
                        size: boxSize,
                        recognition: canvasData.recognitionResults[index]
                    )
                }
            }
            .frame(width: totalWidth)
            
            // Boxes with canvas overlay
            ZStack(alignment: .topLeading) {
                // Grid of boxes (visual guides)
                HStack(spacing: 0) {
                    ForEach(0..<boxCount, id: \.self) { index in
                        CharacterBox(
                            index: index,
                            size: boxSize,
                            hasContent: canvasData.characterData[index]?.isEmpty == false,
                            recognition: canvasData.recognitionResults[index]
                        )
                    }
                }
                
                // Canvas overlay - exactly on top of boxes
                GrammarDrawingCanvas(
                    canvasView: $canvasView,
                    canvasData: canvasData,
                    isErasing: $isErasing,
                    boxSize: boxSize,
                    boxCount: boxCount,
                    boxesStartX: 0,
                    onStrokeAdded: { stroke, boxIndex in
                        canvasData.addStroke(stroke, toBox: boxIndex)
                    }
                )
                .frame(width: totalWidth, height: boxSize)
            }
            .frame(width: totalWidth, height: boxSize)
            
            // Feedback row
            if hasChecked {
                HStack(spacing: 0) {
                    ForEach(0..<boxCount, id: \.self) { index in
                        FeedbackLabel(
                            size: boxSize,
                            feedback: feedbackItems.first { $0.boxIndex == index }
                        )
                    }
                }
                .frame(width: totalWidth)
            }
            
            Spacer()
            
            // Tool buttons
            HStack(spacing: 16) {
                Button(action: { isErasing = false }) {
                    Label("Pen", systemImage: "pencil.tip")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(isErasing ? AppTheme.stone : AppTheme.forestGreen)
                
                Button(action: { isErasing = true }) {
                    Label("Eraser", systemImage: "eraser.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(isErasing ? AppTheme.forestGreen : AppTheme.stone)
                
                Button(action: clearAll) {
                    Label("Clear All", systemImage: "trash")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.error)
            }
            
            // Check / Next buttons
            VStack(spacing: 12) {
                if hasChecked && !lastAnswerWasCorrect {
                    Button(action: overrideAsCorrect) {
                        Label("I was correct", systemImage: "hand.thumbsup")
                            .font(AppTheme.Typography.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.amber)
                }
                
                HStack(spacing: 16) {
                    if !hasChecked {
                        Button(action: checkAnswer) {
                            Text("Check")
                                .font(AppTheme.Typography.headline)
                                .frame(maxWidth: 200)
                                .padding()
                                .background(AppTheme.forestGreen)
                                .foregroundColor(.white)
                                .cornerRadius(AppTheme.Radius.md)
                        }
                    } else {
                        Button(action: loadNewSentence) {
                            Text("Next")
                                .font(AppTheme.Typography.headline)
                                .frame(maxWidth: 200)
                                .padding()
                                .background(AppTheme.forestGreen)
                                .foregroundColor(.white)
                                .cornerRadius(AppTheme.Radius.md)
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadNewSentence()
        }
    }
    
    // MARK: - iPhone Layout (simplified for now)
    private var iPhoneLayout: some View {
        VStack(spacing: 20) {
            Text("Grammar practice is optimized for iPad")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.stone)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func clearAll() {
        canvasData.clearAll()
        canvasView.drawing = PKDrawing()
        hasChecked = false
        feedbackItems = []
    }
    
    private func checkAnswer() {
        // Only trigger recognition for boxes that don't already have results
        for boxIndex in canvasData.characterData.keys {
            let hasRecognition = canvasData.recognitionResults[boxIndex]?.recognizedCharacter != nil
            let isProcessing = canvasData.recognitionResults[boxIndex]?.isProcessing == true
            
            if !hasRecognition && !isProcessing {
                canvasData.triggerRecognition(forBox: boxIndex)
            }
        }
        
        hasChecked = true
        generateFeedback()
        
        // Determine if answer was correct (all feedback items are correct type)
        let allCorrect = feedbackItems.allSatisfy { $0.type == .correct }
        lastAnswerWasCorrect = allCorrect
        practiceStats.recordAnswer(wasCorrect: allCorrect)
    }
    
    private func overrideAsCorrect() {
        practiceStats.overrideAsCorrect()
        lastAnswerWasCorrect = true
    }
    
    private func generateFeedback() {
        feedbackItems = []
        
        // Get user's recognized characters in order
        var userChars: [String?] = []
        for i in 0..<boxCount {
            userChars.append(canvasData.recognitionResults[i]?.recognizedCharacter)
        }
        
        // Get correct characters
        let correctChars = Array(chineseSentence)
        
        // Simple comparison - align user input with correct answer
        var feedbackIndex = 0
        var correctIndex = 0
        
        while feedbackIndex < boxCount || correctIndex < correctChars.count {
            let userChar = feedbackIndex < boxCount ? userChars[feedbackIndex] : nil
            let correctChar = correctIndex < correctChars.count ? String(correctChars[correctIndex]) : nil
            
            if let user = userChar, let correct = correctChar {
                if user == correct {
                    // Correct
                    feedbackItems.append(FeedbackItem(
                        boxIndex: feedbackIndex,
                        type: .correct,
                        userChar: user,
                        correctChar: correct
                    ))
                    // Update beta distribution - success for this character
                    betaStore.recordSuccess(for: correct)
                    feedbackIndex += 1
                    correctIndex += 1
                } else {
                    // Wrong character - show correction
                    feedbackItems.append(FeedbackItem(
                        boxIndex: feedbackIndex,
                        type: .wrong,
                        userChar: user,
                        correctChar: correct
                    ))
                    // Update beta distribution - failure for the expected character
                    betaStore.recordFailure(for: correct)
                    feedbackIndex += 1
                    correctIndex += 1
                }
            } else if userChar == nil && correctChar != nil {
                // User omitted a character
                feedbackItems.append(FeedbackItem(
                    boxIndex: feedbackIndex < boxCount ? feedbackIndex : boxCount - 1,
                    type: .missing,
                    userChar: nil,
                    correctChar: correctChar
                ))
                // Update beta distribution - failure for the missing character
                betaStore.recordFailure(for: correctChar!)
                correctIndex += 1
                if feedbackIndex < boxCount { feedbackIndex += 1 }
            } else if userChar != nil && correctChar == nil {
                // User wrote extra character
                feedbackItems.append(FeedbackItem(
                    boxIndex: feedbackIndex,
                    type: .extra,
                    userChar: userChar,
                    correctChar: nil
                ))
                feedbackIndex += 1
            } else {
                // Both nil - empty box, no more correct chars
                feedbackIndex += 1
            }
        }
    }
    
    private func loadNewSentence() {
        isLoadingSentence = true
        loadError = nil
        
        // Pass active characters to bias the LLM toward weak characters
        let activeChars = store.allActiveCharacters
        
        ChatGPTAPI.shared.generateSentence(activeCharacters: activeChars) { result in
            DispatchQueue.main.async {
                isLoadingSentence = false
                
                switch result {
                case .success(let response):
                    englishSentence = response.english
                    chineseSentence = response.chinese
                    // Set allowed characters: ONLY use active chars for recognition
                    canvasData.allowedCharacters = activeChars
                    // Clear canvas for new sentence
                    clearAll()
                case .failure(let error):
                    loadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Character Box
struct CharacterBox: View {
    let index: Int
    let size: CGFloat
    let hasContent: Bool
    var recognition: CharacterRecognition?
    
    private var borderColor: Color {
        guard let recognition = recognition else {
            return AppTheme.stone.opacity(0.4)
        }
        if recognition.isProcessing {
            return AppTheme.amber
        }
        if recognition.recognizedCharacter != nil {
            return AppTheme.forestGreen
        }
        if hasContent && recognition.confidence < 0.3 {
            return AppTheme.error.opacity(0.6)
        }
        return AppTheme.stone.opacity(0.4)
    }
    
    var body: some View {
        ZStack {
            // Dark background for white ink visibility
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .frame(width: size, height: size)
            
            Rectangle()
                .strokeBorder(borderColor, lineWidth: recognition?.recognizedCharacter != nil ? 2 : 1)
                .frame(width: size, height: size)
            
            // Cross guidelines
            Path { path in
                path.move(to: CGPoint(x: size / 2, y: 0))
                path.addLine(to: CGPoint(x: size / 2, y: size))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
            .foregroundColor(AppTheme.stone.opacity(0.3))
            .frame(width: size, height: size)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: size / 2))
                path.addLine(to: CGPoint(x: size, y: size / 2))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
            .foregroundColor(AppTheme.stone.opacity(0.3))
            .frame(width: size, height: size)
            
            // Processing indicator
            if recognition?.isProcessing == true {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
    }
}

// MARK: - Recognition Label
struct RecognitionLabel: View {
    let size: CGFloat
    var recognition: CharacterRecognition?
    
    var body: some View {
        VStack(spacing: 2) {
            if let char = recognition?.recognizedCharacter {
                Text(char)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.forestGreen)
            } else if recognition?.isProcessing == true {
                Text("...")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.stone)
            } else {
                Text("")
                    .font(.system(size: 16))
            }
        }
        .frame(width: size, height: 24)
    }
}

// MARK: - Feedback Label
struct FeedbackLabel: View {
    let size: CGFloat
    var feedback: FeedbackItem?
    
    var body: some View {
        VStack(spacing: 2) {
            if let fb = feedback {
                switch fb.type {
                case .correct:
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.forestGreen)
                case .wrong:
                    Text(fb.correctChar ?? "")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.error)
                case .missing:
                    Text(fb.correctChar ?? "")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.amber)
                case .extra:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.error.opacity(0.7))
                }
            } else {
                Text("")
                    .font(.system(size: 16))
            }
        }
        .frame(width: size, height: 28)
    }
}

// MARK: - Grammar Drawing Canvas
struct GrammarDrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @ObservedObject var canvasData: GrammarCanvasData
    @Binding var isErasing: Bool
    let boxSize: CGFloat
    let boxCount: Int
    var boxesStartX: CGFloat = 0
    let onStrokeAdded: (PKStroke, Int) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        // Use marker - it doesn't adapt colors like pen does
        let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        canvasView.tool = PKInkingTool(ink: ink, width: 6)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if isErasing {
            uiView.tool = PKEraserTool(.vector)
        } else {
            let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
            uiView.tool = PKInkingTool(ink: ink, width: 6)
        }
        // Update coordinator with current boxesStartX
        context.coordinator.boxesStartX = boxesStartX
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            canvasData: canvasData,
            boxSize: boxSize,
            boxCount: boxCount,
            boxesStartX: boxesStartX,
            onStrokeAdded: onStrokeAdded
        )
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let canvasData: GrammarCanvasData
        let boxSize: CGFloat
        let boxCount: Int
        var boxesStartX: CGFloat
        let onStrokeAdded: (PKStroke, Int) -> Void
        
        private var previousStrokeCount: Int = 0
        private var previousStrokesByBox: [Int: Int] = [:]
        
        init(canvasData: GrammarCanvasData, boxSize: CGFloat, boxCount: Int,
             boxesStartX: CGFloat, onStrokeAdded: @escaping (PKStroke, Int) -> Void) {
            self.canvasData = canvasData
            self.boxSize = boxSize
            self.boxCount = boxCount
            self.boxesStartX = boxesStartX
            self.onStrokeAdded = onStrokeAdded
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Force white marker ink when user starts drawing (unless erasing)
            if canvasView.tool is PKInkingTool {
                let ink = PKInk(.marker, color: UIColor(red: 1, green: 1, blue: 1, alpha: 1))
                canvasView.tool = PKInkingTool(ink: ink, width: 6)
            }
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let currentStrokes = canvasView.drawing.strokes
            let currentCount = currentStrokes.count
            
            // Group strokes by box
            var strokesByBox: [Int: [PKStroke]] = [:]
            for stroke in currentStrokes {
                let boxIndex = determineBoxIndex(for: stroke)
                if boxIndex >= 0 && boxIndex < boxCount {
                    if strokesByBox[boxIndex] == nil {
                        strokesByBox[boxIndex] = []
                    }
                    strokesByBox[boxIndex]?.append(stroke)
                }
            }
            
            // Check for new strokes (count increased)
            if currentCount > previousStrokeCount {
                // Find the new stroke (last one added)
                if let lastStroke = currentStrokes.last {
                    let boxIndex = determineBoxIndex(for: lastStroke)
                    if boxIndex >= 0 && boxIndex < boxCount {
                        onStrokeAdded(lastStroke, boxIndex)
                    }
                }
            }
            
            // Check for removed strokes (erased) - sync each box
            for boxIndex in 0..<boxCount {
                let currentBoxStrokes = strokesByBox[boxIndex] ?? []
                let previousBoxCount = previousStrokesByBox[boxIndex] ?? 0
                
                if currentBoxStrokes.count != previousBoxCount {
                    // Strokes changed in this box - sync
                    DispatchQueue.main.async {
                        self.canvasData.syncStrokes(forBox: boxIndex, strokes: currentBoxStrokes)
                    }
                }
                previousStrokesByBox[boxIndex] = currentBoxStrokes.count
            }
            
            previousStrokeCount = currentCount
        }
        
        private func determineBoxIndex(for stroke: PKStroke) -> Int {
            // Get the center point of the stroke's bounding box
            let bounds = stroke.renderBounds
            let centerX = bounds.midX
            
            // Adjust for box offset and determine which box
            let adjustedX = centerX - boxesStartX
            let boxIndex = Int(adjustedX / boxSize)
            return min(max(boxIndex, 0), boxCount - 1)
        }
    }
}

#Preview {
    NavigationStack {
        GrammarPracticeView()
    }
}
