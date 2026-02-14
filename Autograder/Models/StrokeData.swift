import Foundation
import CoreGraphics

struct SampledPoint: Codable {
    let x: CGFloat
    let y: CGFloat
    
    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    init(from point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct SubstrokeData: Codable, Identifiable {
    let id: UUID
    let points: [SampledPoint]
    let substrokeIndex: Int
    
    init(id: UUID = UUID(), points: [SampledPoint], substrokeIndex: Int) {
        self.id = id
        self.points = points
        self.substrokeIndex = substrokeIndex
    }
}

struct StrokeData: Codable, Identifiable {
    let id: UUID
    let substrokes: [SubstrokeData]
    let strokeIndex: Int
    
    init(id: UUID = UUID(), substrokes: [SubstrokeData], strokeIndex: Int) {
        self.id = id
        self.substrokes = substrokes
        self.strokeIndex = strokeIndex
    }
    
    var totalSubstrokes: Int {
        substrokes.count
    }
    
    var totalPoints: Int {
        substrokes.reduce(0) { $0 + $1.points.count }
    }
}

struct CharacterAttemptData: Codable, Identifiable {
    let id: UUID
    let flashcardId: UUID
    let term: String
    let definition: String
    let strokes: [StrokeData]
    let timestamp: Date
    let sampleDistance: CGFloat
    
    init(
        id: UUID = UUID(),
        flashcardId: UUID,
        term: String,
        definition: String,
        strokes: [StrokeData],
        timestamp: Date = Date(),
        sampleDistance: CGFloat
    ) {
        self.id = id
        self.flashcardId = flashcardId
        self.term = term
        self.definition = definition
        self.strokes = strokes
        self.timestamp = timestamp
        self.sampleDistance = sampleDistance
    }
    
    var totalStrokes: Int {
        strokes.count
    }
    
    var totalSubstrokes: Int {
        strokes.reduce(0) { $0 + $1.totalSubstrokes }
    }
    
    var totalPoints: Int {
        strokes.reduce(0) { $0 + $1.totalPoints }
    }
}
