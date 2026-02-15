import SwiftUI
import PencilKit

struct FlashcardModeView: View {
    @EnvironmentObject var store: FlashcardStore
    @ObservedObject var practiceStats = PracticeStats.shared
    @ObservedObject var betaStore = CharacterBetaStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var studyQueue: [Flashcard] = []
    @State private var currentQueueIndex = 0
    @State private var canvasView = PKCanvasView()
    @State private var strokeColor: UIColor = .white
    @State private var hasChecked = false
    @State private var strokeCount = 0
    @State private var showingDeckPicker = false
    @State private var debugInfo: String = ""
    @State private var lastAttemptData: CharacterAttemptData?
    @State private var sampledPointsForDisplay: [[CGPoint]] = []
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    @State private var showingStrokeAssignment = false
    @State private var isCheckingAnswer = false
    @State private var lastGradeResponse: AutograderResponse? = nil
    @State private var strokeStatuses: [StrokeStatus] = []
    @State private var sessionStartTime: Date = Date()
    @State private var showingSessionComplete = false
    @State private var lastAnswerWasCorrect = true
    
    private let pointsPerStroke: Int = 50
    private let sampler = StrokeSampler(pointsPerStroke: 50)
    
    var currentDeck: FlashcardDeck? {
        store.selectedDeck
    }
    
    var currentCard: Flashcard? {
        guard !studyQueue.isEmpty, currentQueueIndex < studyQueue.count else { return nil }
        return studyQueue[currentQueueIndex]
    }
    
    var remainingCards: Int {
        max(0, studyQueue.count - currentQueueIndex)
    }
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        let canvasSize: CGFloat = isIPad ? 450 : min(UIScreen.main.bounds.width - 48, 340)
        
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let deck = currentDeck, !deck.cards.isEmpty, let card = currentCard {
                    // Header row
                    HStack {
                        Text("\(currentQueueIndex + 1) / \(studyQueue.count)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        
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
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Centered content
                    VStack(spacing: isIPad ? 24 : 16) {
                        Text(card.definition)
                            .font(isIPad ? AppTheme.Typography.largeTitle : AppTheme.Typography.title)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        ZStack {
                        ChineseCharacterGrid(size: canvasSize)
                        
                        DrawingCanvasView(
                            canvasView: $canvasView,
                            strokeColor: $strokeColor,
                            onDrawingChanged: {
                                strokeCount = canvasView.drawing.strokes.count
                            }
                        )
                        .frame(width: canvasSize, height: canvasSize)
                        .clipShape(Rectangle())
                        
                    }
                    .frame(width: canvasSize, height: canvasSize)
                    
                    HStack(spacing: 16) {
                        Button(action: undoStroke) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.stone)
                        .disabled(canvasView.drawing.strokes.isEmpty)
                        
                        Button(action: clearCanvas) {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.error)
                        .disabled(canvasView.drawing.strokes.isEmpty)
                    }
                    
                    if !debugInfo.isEmpty {
                        Text(debugInfo)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal)
                    }
                    
                    }
                    // End of centered VStack
                    
                    Spacer()
                    
                    // Bottom section - checked results or check button
                    if hasChecked {
                        VStack(spacing: 12) {
                            Text("Correct character:")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text(card.term)
                                .font(.system(size: isIPad ? 80 : 60))
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.forestGreen)
                            
                            if !lastAnswerWasCorrect {
                                Button(action: overrideAsCorrect) {
                                    Label("I was correct", systemImage: "hand.thumbsup")
                                        .font(AppTheme.Typography.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(AppTheme.amber)
                            }
                            
                            Button(action: { rateAndNext(quality: .good) }) {
                                Text("Next")
                                    .font(AppTheme.Typography.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppTheme.forestGreen)
                                    .foregroundColor(.white)
                                    .cornerRadius(AppTheme.Radius.md)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    } else {
                        HStack(spacing: 16) {
                            if !isCheckingAnswer {
                                Button(action: checkAnswer) {
                                    Label("Check", systemImage: "checkmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.forestGreen)
                                .disabled(strokeCount < 1)
                            } else {
                                ProgressView()
                                    .tint(AppTheme.forestGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            
                            Button(action: skipCard) {
                                Label("Skip", systemImage: "forward.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.stone)
                        }
                        .frame(maxWidth: isIPad ? 400 : .infinity)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                } else {
                    ContentUnavailableView(
                        "No Flashcards",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Select a deck or create flashcards to start practicing")
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(store.decks) { deck in
                        Button(action: {
                            store.selectedDeckId = deck.id
                            resetForNewDeck()
                        }) {
                            HStack {
                                Text(deck.name)
                                if deck.id == store.selectedDeckId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentDeck?.name ?? "Select Deck")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.forestGreen)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.forestGreen)
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingStrokeAssignment) {
            if let card = currentCard {
                StrokeAssignmentSheet(
                    strokes: Array(canvasView.drawing.strokes),
                    character: card.term,
                    definition: card.definition,
                    canvasSize: horizontalSizeClass == .regular ? 450 : min(UIScreen.main.bounds.width - 48, 340),
                    onSave: { dataPoint, datasetName in
                        ValidationDatasetManager.shared.addDataPoint(dataPoint, toDatasetNamed: datasetName)
                        showingStrokeAssignment = false
                    },
                    onCancel: {
                        showingStrokeAssignment = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSessionComplete) {
            SessionCompleteView(stats: store.currentSessionStats) {
                showingSessionComplete = false
                resetForNewDeck()
            }
        }
        .onAppear {
            loadStudyQueue()
            store.startNewSession()
            sessionStartTime = Date()
        }
        .onChange(of: store.selectedDeckId) { _, _ in
            resetForNewDeck()
        }
    }
    
    private func undoStroke() {
        guard !canvasView.drawing.strokes.isEmpty else { return }
        var drawing = canvasView.drawing
        drawing.strokes.removeLast()
        canvasView.drawing = drawing
        strokeCount = drawing.strokes.count
    }
    
    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        strokeCount = 0
        hasChecked = false
        strokeColor = .white
        debugInfo = ""
        sampledPointsForDisplay = []
        strokeStatuses = []
        lastGradeResponse = nil
    }
    
    private func checkAnswer() {
        guard let card = currentCard else { return }
        
        isCheckingAnswer = true
        strokeStatuses = []
        lastGradeResponse = nil
        
        // Collect stroke points for API
        var strokePoints: [[CGPoint]] = []
        var allStrokeData: [StrokeData] = []
        
        for (strokeIndex, stroke) in canvasView.drawing.strokes.enumerated() {
            let sampledPoints = sampler.samplePoints(from: stroke.path, startIndex: 0, endIndex: stroke.path.count - 1)
            let cgPoints = sampledPoints.map { $0.cgPoint }
            strokePoints.append(cgPoints)
            let substrokeData = SubstrokeData(points: sampledPoints, substrokeIndex: 0)
            let strokeData = StrokeData(substrokes: [substrokeData], strokeIndex: strokeIndex)
            allStrokeData.append(strokeData)
        }
        
        lastAttemptData = CharacterAttemptData(
            flashcardId: card.id,
            term: card.term,
            definition: card.definition,
            strokes: allStrokeData,
            pointsPerStroke: pointsPerStroke
        )
        
        sampledPointsForDisplay = strokePoints
        
        // Call API to classify strokes
        AutograderAPI.shared.classifyStrokes(character: card.term, strokes: strokePoints) { result in
            DispatchQueue.main.async {
                self.isCheckingAnswer = false
                self.hasChecked = true
                
                switch result {
                case .success(let response):
                    self.lastGradeResponse = response
                    self.strokeStatuses = AutograderAPI.getStrokeStatuses(from: response)
                    self.applyStrokeColors(statuses: self.strokeStatuses)
                    
                    // Determine if answer was correct (all strokes correct)
                    let allCorrect = self.strokeStatuses.allSatisfy { $0 == .correct }
                    self.lastAnswerWasCorrect = allCorrect
                    self.practiceStats.recordAnswer(wasCorrect: allCorrect)
                    
                    // Update beta distribution for this character
                    if allCorrect {
                        self.betaStore.recordSuccess(for: card.term)
                    } else {
                        self.betaStore.recordFailure(for: card.term)
                    }
                    
                case .failure(let error):
                    print("API Error: \(error)")
                    self.debugInfo = "Error checking strokes"
                    // On error, assume correct to not penalize user
                    self.lastAnswerWasCorrect = true
                    self.practiceStats.recordAnswer(wasCorrect: true)
                }
            }
        }
    }
    
    private func applyStrokeColors(statuses: [StrokeStatus]) {
        var newDrawing = PKDrawing()
        
        for (index, stroke) in canvasView.drawing.strokes.enumerated() {
            var newStroke = stroke
            
            let color: UIColor
            if index < statuses.count {
                switch statuses[index] {
                case .correct:
                    color = .systemGreen
                case .wrongOrder:
                    color = .systemYellow
                case .incorrect:
                    color = .systemRed
                }
            } else {
                color = .white
            }
            
            newStroke.ink = PKInk(.pen, color: color)
            newDrawing.strokes.append(newStroke)
        }
        
        canvasView.drawing = newDrawing
    }
    
    private func exportCharacterData() {
        guard let attemptData = lastAttemptData else { return }
        
        var csvContent = "character,stroke,substroke,point_index,x,y\n"
        
        for stroke in attemptData.strokes {
            for substroke in stroke.substrokes {
                for (pointIndex, point) in substroke.points.enumerated() {
                    csvContent += "\(attemptData.term),\(stroke.strokeIndex),\(substroke.substrokeIndex),\(pointIndex),\(String(format: "%.2f", point.x)),\(String(format: "%.2f", point.y))\n"
                }
            }
        }
        
        let fileName = "\(attemptData.term)_\(Int(attemptData.timestamp.timeIntervalSince1970)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showingShareSheet = true
        } catch {
            print("Failed to write file: \(error)")
        }
    }
    
    private func nextCard() {
        withAnimation {
            currentQueueIndex += 1
        }
        
        if currentQueueIndex >= studyQueue.count {
            showingSessionComplete = true
            store.endSession()
        } else {
            clearCanvas()
        }
    }
    
    private func skipCard() {
        nextCard()
    }
    
    private func overrideAsCorrect() {
        practiceStats.overrideAsCorrect()
        lastAnswerWasCorrect = true
    }
    
    private func rateAndNext(quality: ReviewQuality) {
        guard let deck = currentDeck, let card = currentCard else { return }
        store.reviewCard(deckId: deck.id, cardId: card.id, quality: quality)
        nextCard()
    }
    
    private func nextIntervalText(for quality: ReviewQuality) -> String {
        guard let card = currentCard else { return "" }
        
        var testData = card.srsData
        testData.review(quality: quality)
        
        let interval = testData.interval
        if interval == 1 {
            return "1d"
        } else if interval < 30 {
            return "\(interval)d"
        } else if interval < 365 {
            return "\(interval / 30)mo"
        } else {
            return "\(interval / 365)y"
        }
    }
    
    private func resetForNewDeck() {
        currentQueueIndex = 0
        sessionStartTime = Date()
        store.startNewSession()
        loadStudyQueue()
        clearCanvas()
    }
    
    private func loadStudyQueue() {
        guard let deckId = store.selectedDeckId else {
            studyQueue = []
            return
        }
        studyQueue = store.getStudyQueue(forDeckId: deckId)
    }
}

// SRS Rating Button Component
struct SRSRatingButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(AppTheme.Radius.md)
        }
    }
}

// Session Complete View
struct SessionCompleteView: View {
    let stats: StudySessionStats
    let onContinue: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(AppTheme.forestGreen.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(AppTheme.forestGreen)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Session Complete!")
                            .font(AppTheme.Typography.title)
                            .foregroundColor(AppTheme.gold)
                        
                        Text("Great work on your practice!")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    VStack(spacing: 12) {
                        StatRow(title: "Cards Studied", value: "\(stats.cardsStudied)", color: AppTheme.textPrimary)
                        StatRow(title: "New Cards", value: "\(stats.newCardsStudied)", color: AppTheme.forestGreen)
                        StatRow(title: "Correct", value: "\(stats.correctCount)", color: AppTheme.success)
                        StatRow(title: "Incorrect", value: "\(stats.incorrectCount)", color: AppTheme.error)
                        
                        if stats.cardsStudied > 0 {
                            Divider()
                            StatRow(title: "Accuracy", value: "\(Int(stats.accuracy * 100))%", color: stats.accuracy >= 0.8 ? AppTheme.success : AppTheme.amber)
                        }
                    }
                    .padding(20)
                    .background(AppTheme.backgroundCard)
                    .cornerRadius(AppTheme.Radius.lg)
                    .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: onContinue) {
                        Text("Continue Studying")
                            .font(AppTheme.Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.forestGreen)
                            .foregroundColor(.white)
                            .cornerRadius(AppTheme.Radius.md)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Great Work!")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.forestGreen)
                }
            }
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var color: Color = AppTheme.textPrimary
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundColor(color)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        FlashcardModeView()
            .environmentObject(FlashcardStore())
    }
}
