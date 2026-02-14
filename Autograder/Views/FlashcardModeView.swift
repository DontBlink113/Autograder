import SwiftUI
import PencilKit

struct FlashcardModeView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var currentCardIndex = 0
    @State private var canvasView = PKCanvasView()
    @State private var strokeColor: UIColor = .black
    @State private var hasChecked = false
    @State private var strokeCount = 0
    @State private var showingDeckPicker = false
    @State private var debugInfo: String = ""
    @State private var lastAttemptData: CharacterAttemptData?
    @State private var sampledPointsForDisplay: [[CGPoint]] = []
    
    private let sampleDistance: CGFloat = 5.0
    private let sampler = StrokeSampler(sampleDistance: 5.0)
    
    var currentDeck: FlashcardDeck? {
        store.selectedDeck
    }
    
    var currentCard: Flashcard? {
        guard let deck = currentDeck, !deck.cards.isEmpty else { return nil }
        return deck.cards[currentCardIndex % deck.cards.count]
    }
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        let canvasSize: CGFloat = isIPad ? 450 : min(UIScreen.main.bounds.width - 48, 340)
        
        VStack(spacing: 0) {
            if let deck = currentDeck, !deck.cards.isEmpty, let card = currentCard {
                VStack(spacing: isIPad ? 24 : 16) {
                    HStack {
                        Text("\(currentCardIndex + 1) / \(deck.cards.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        Text("Write the character for:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(card.definition)
                            .font(isIPad ? .largeTitle : .title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
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
                        
                        if hasChecked && !sampledPointsForDisplay.isEmpty {
                            SampledPointsOverlay(pointGroups: sampledPointsForDisplay)
                                .frame(width: canvasSize, height: canvasSize)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: canvasSize, height: canvasSize)
                    
                    HStack(spacing: 16) {
                        Button(action: undoStroke) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)
                        .disabled(canvasView.drawing.strokes.isEmpty)
                        
                        Button(action: clearCanvas) {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(canvasView.drawing.strokes.isEmpty)
                    }
                    
                    if !debugInfo.isEmpty {
                        Text(debugInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    
                    if hasChecked {
                        VStack(spacing: 8) {
                            Text("Correct character:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(card.term)
                                .font(.system(size: isIPad ? 80 : 60))
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if !hasChecked {
                            Button(action: checkAnswer) {
                                Label("Check", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(strokeCount < 1)
                        }
                        
                        Button(action: nextCard) {
                            Label("Next", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .frame(maxWidth: isIPad ? 400 : .infinity)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            } else {
                ContentUnavailableView(
                    "No Flashcards",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Select a deck or create flashcards to start practicing")
                )
            }
        }
        .navigationTitle("Practice")
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
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
            }
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
        strokeColor = .black
        debugInfo = ""
        sampledPointsForDisplay = []
    }
    
    private let substrokeColors: [UIColor] = [
        .systemGreen,
        .systemBlue,
        .systemPurple,
        .systemYellow
    ]
    
    private let pauseThreshold: TimeInterval = 0.03
    
    private func checkAnswer() {
        hasChecked = true
        strokeColor = UIColor.systemGreen
        
        guard let card = currentCard else { return }
        
        var newDrawing = PKDrawing()
        var substrokeCounts: [Int] = []
        var allStrokeData: [StrokeData] = []
        
        for (strokeIndex, stroke) in canvasView.drawing.strokes.enumerated() {
            let (substrokes, substrokeDataList) = splitStrokeIntoSubstrokesWithData(stroke, strokeIndex: strokeIndex)
            substrokeCounts.append(substrokes.count)
            newDrawing.strokes.append(contentsOf: substrokes)
            
            let strokeData = StrokeData(substrokes: substrokeDataList, strokeIndex: strokeIndex)
            allStrokeData.append(strokeData)
        }
        
        lastAttemptData = CharacterAttemptData(
            flashcardId: card.id,
            term: card.term,
            definition: card.definition,
            strokes: allStrokeData,
            sampleDistance: sampleDistance
        )
        
        let totalStrokes = substrokeCounts.count
        let substrokeDetails = substrokeCounts.enumerated().map { "S\($0.offset + 1):\($0.element)" }.joined(separator: " ")
        let totalPoints = lastAttemptData?.totalPoints ?? 0
        debugInfo = "Strokes: \(totalStrokes) | Substrokes: \(substrokeDetails) | Points: \(totalPoints)"
        
        canvasView.drawing = newDrawing
        
        sampledPointsForDisplay = lastAttemptData?.strokes.flatMap { stroke in
            stroke.substrokes.map { substroke in
                substroke.points.map { $0.cgPoint }
            }
        } ?? []
    }
    
    private func splitStrokeIntoSubstrokes(_ stroke: PKStroke) -> [PKStroke] {
        let path = stroke.path
        guard path.count > 1 else {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: substrokeColors[0])
            return [newStroke]
        }
        
        var breakIndices: [Int] = []
        
        for i in 1..<path.count {
            let prevPoint = path[i - 1]
            let currPoint = path[i]
            
            let timeDiff = currPoint.timeOffset - prevPoint.timeOffset
            
            if timeDiff > pauseThreshold {
                if i > 1 {
                    breakIndices.append(i)
                }
            }
        }
        
        if breakIndices.isEmpty {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: substrokeColors[0])
            return [newStroke]
        }
        
        var substrokeRanges: [(start: Int, end: Int)] = []
        var currentStart = 0
        
        for breakIndex in breakIndices {
            substrokeRanges.append((start: currentStart, end: breakIndex - 1))
            currentStart = breakIndex
        }
        
        substrokeRanges.append((start: currentStart, end: path.count - 1))
        
        var resultStrokes: [PKStroke] = []
        var actualSubstrokeIndex = 0
        
        for range in substrokeRanges {
            guard range.end >= range.start else { continue }
            
            var points: [PKStrokePoint] = []
            for i in range.start...range.end {
                points.append(path[i])
            }
            
            guard points.count > 1 else { continue }
            
            let colorIndex = actualSubstrokeIndex % substrokeColors.count
            let color = substrokeColors[colorIndex]
            
            let newPath = PKStrokePath(controlPoints: points, creationDate: Date())
            let newInk = PKInk(.pen, color: color)
            let newStroke = PKStroke(ink: newInk, path: newPath)
            
            resultStrokes.append(newStroke)
            actualSubstrokeIndex += 1
        }
        
        if resultStrokes.isEmpty {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: substrokeColors[0])
            return [newStroke]
        }
        
        return resultStrokes
    }
    
    private func splitStrokeIntoSubstrokesWithData(_ stroke: PKStroke, strokeIndex: Int) -> ([PKStroke], [SubstrokeData]) {
        let path = stroke.path
        guard path.count > 1 else {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: substrokeColors[0])
            let sampledPoints = sampler.samplePointsAlongDistance(from: path, startIndex: 0, endIndex: path.count - 1)
            let substrokeData = SubstrokeData(points: sampledPoints, substrokeIndex: 0)
            return ([newStroke], [substrokeData])
        }
        
        var breakIndices: [Int] = []
        
        for i in 1..<path.count {
            let prevPoint = path[i - 1]
            let currPoint = path[i]
            
            let timeDiff = currPoint.timeOffset - prevPoint.timeOffset
            
            if timeDiff > pauseThreshold {
                if i > 1 {
                    breakIndices.append(i)
                }
            }
        }
        
        if breakIndices.isEmpty {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: substrokeColors[0])
            let sampledPoints = sampler.samplePointsAlongDistance(from: path, startIndex: 0, endIndex: path.count - 1)
            let substrokeData = SubstrokeData(points: sampledPoints, substrokeIndex: 0)
            return ([newStroke], [substrokeData])
        }
        
        var substrokeRanges: [(start: Int, end: Int)] = []
        var currentStart = 0
        
        for breakIndex in breakIndices {
            substrokeRanges.append((start: currentStart, end: breakIndex - 1))
            currentStart = breakIndex
        }
        
        substrokeRanges.append((start: currentStart, end: path.count - 1))
        
        var resultStrokes: [PKStroke] = []
        var resultSubstrokeData: [SubstrokeData] = []
        var actualSubstrokeIndex = 0
        
        for range in substrokeRanges {
            guard range.end >= range.start else { continue }
            
            var points: [PKStrokePoint] = []
            for i in range.start...range.end {
                points.append(path[i])
            }
            
            guard points.count > 1 else { continue }
            
            let colorIndex = actualSubstrokeIndex % substrokeColors.count
            let color = substrokeColors[colorIndex]
            
            let newPath = PKStrokePath(controlPoints: points, creationDate: Date())
            let newInk = PKInk(.pen, color: color)
            let newStroke = PKStroke(ink: newInk, path: newPath)
            
            resultStrokes.append(newStroke)
            
            let sampledPoints = sampler.samplePointsAlongDistance(from: path, startIndex: range.start, endIndex: range.end)
            let substrokeData = SubstrokeData(points: sampledPoints, substrokeIndex: actualSubstrokeIndex)
            resultSubstrokeData.append(substrokeData)
            
            actualSubstrokeIndex += 1
        }
        
        if resultStrokes.isEmpty {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: substrokeColors[0])
            let sampledPoints = sampler.samplePointsAlongDistance(from: path, startIndex: 0, endIndex: path.count - 1)
            let substrokeData = SubstrokeData(points: sampledPoints, substrokeIndex: 0)
            return ([newStroke], [substrokeData])
        }
        
        return (resultStrokes, resultSubstrokeData)
    }
    
    private func nextCard() {
        guard let deck = currentDeck, !deck.cards.isEmpty else { return }
        
        withAnimation {
            currentCardIndex = (currentCardIndex + 1) % deck.cards.count
        }
        
        clearCanvas()
    }
    
    private func resetForNewDeck() {
        currentCardIndex = 0
        clearCanvas()
    }
}

#Preview {
    NavigationStack {
        FlashcardModeView()
            .environmentObject(FlashcardStore())
    }
}
