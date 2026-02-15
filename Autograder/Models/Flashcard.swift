import Foundation

// SM-2 Spaced Repetition Algorithm
// Quality ratings: 0-2 = fail (reset), 3 = hard, 4 = good, 5 = easy

enum ReviewQuality: Int, Codable {
    case completeBlackout = 0    // Complete failure
    case incorrect = 1           // Incorrect but recognized
    case incorrectEasy = 2       // Incorrect but easy to recall
    case hard = 3                // Correct with difficulty
    case good = 4                // Correct with some hesitation
    case easy = 5                // Perfect recall
}

struct SpacedRepetitionData: Codable, Hashable {
    var easeFactor: Double       // EF starts at 2.5
    var interval: Int            // Days until next review
    var repetitions: Int         // Number of successful reviews in a row
    var nextReviewDate: Date     // When to review next
    var lastReviewDate: Date?    // Last time reviewed
    var totalReviews: Int        // Total number of reviews
    var correctReviews: Int      // Number of correct reviews
    
    init() {
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
        self.nextReviewDate = Date()
        self.lastReviewDate = nil
        self.totalReviews = 0
        self.correctReviews = 0
    }
    
    var accuracy: Double {
        guard totalReviews > 0 else { return 0 }
        return Double(correctReviews) / Double(totalReviews)
    }
    
    var isDue: Bool {
        return Date() >= nextReviewDate
    }
    
    var isNew: Bool {
        return totalReviews == 0
    }
    
    mutating func review(quality: ReviewQuality) {
        totalReviews += 1
        lastReviewDate = Date()
        
        if quality.rawValue >= 3 {
            // Correct response
            correctReviews += 1
            
            if repetitions == 0 {
                interval = 1
            } else if repetitions == 1 {
                interval = 6
            } else {
                interval = Int(Double(interval) * easeFactor)
            }
            repetitions += 1
            
            // Update ease factor using SM-2 formula
            let q = Double(quality.rawValue)
            easeFactor = max(1.3, easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
        } else {
            // Incorrect response - reset
            repetitions = 0
            interval = 1
        }
        
        // Calculate next review date
        nextReviewDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }
}

struct Flashcard: Identifiable, Codable, Hashable {
    let id: UUID
    var term: String
    var definition: String
    var createdAt: Date
    var srsData: SpacedRepetitionData
    var tags: [String]
    var notes: String
    
    init(id: UUID = UUID(), term: String, definition: String, createdAt: Date = Date(), tags: [String] = [], notes: String = "") {
        self.id = id
        self.term = term
        self.definition = definition
        self.createdAt = createdAt
        self.srsData = SpacedRepetitionData()
        self.tags = tags
        self.notes = notes
    }
    
    var isDue: Bool { srsData.isDue }
    var isNew: Bool { srsData.isNew }
    
    mutating func review(quality: ReviewQuality) {
        srsData.review(quality: quality)
    }
}

struct FlashcardDeck: Identifiable, Codable {
    let id: UUID
    var name: String
    var cards: [Flashcard]
    var createdAt: Date
    var description: String
    var dailyNewCardLimit: Int
    var dailyReviewLimit: Int
    var isActive: Bool  // Whether this deck's characters are being actively studied
    
    init(id: UUID = UUID(), name: String, cards: [Flashcard] = [], createdAt: Date = Date(), description: String = "", dailyNewCardLimit: Int = 20, dailyReviewLimit: Int = 100, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.cards = cards
        self.createdAt = createdAt
        self.description = description
        self.dailyNewCardLimit = dailyNewCardLimit
        self.dailyReviewLimit = dailyReviewLimit
        self.isActive = isActive
    }
    
    // All unique characters in this deck
    var allCharacters: String {
        cards.map { $0.term }.joined()
    }
    
    var dueCards: [Flashcard] {
        cards.filter { $0.isDue && !$0.isNew }
    }
    
    var newCards: [Flashcard] {
        cards.filter { $0.isNew }
    }
    
    var learnedCards: [Flashcard] {
        cards.filter { !$0.isNew }
    }
    
    var dueCount: Int { dueCards.count }
    var newCount: Int { newCards.count }
    
    var totalAccuracy: Double {
        let reviewed = cards.filter { $0.srsData.totalReviews > 0 }
        guard !reviewed.isEmpty else { return 0 }
        let totalCorrect = reviewed.reduce(0) { $0 + $1.srsData.correctReviews }
        let totalReviews = reviewed.reduce(0) { $0 + $1.srsData.totalReviews }
        guard totalReviews > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalReviews)
    }
    
    // Get cards for today's study session
    func getStudyQueue(newLimit: Int? = nil, reviewLimit: Int? = nil) -> [Flashcard] {
        let maxNew = newLimit ?? dailyNewCardLimit
        let maxReview = reviewLimit ?? dailyReviewLimit
        
        var queue: [Flashcard] = []
        
        // Add due cards first (sorted by due date)
        let due = dueCards.sorted { $0.srsData.nextReviewDate < $1.srsData.nextReviewDate }
        queue.append(contentsOf: due.prefix(maxReview))
        
        // Add new cards
        let new = newCards
        queue.append(contentsOf: new.prefix(maxNew))
        
        return queue
    }
}

// Study session statistics
struct StudySessionStats: Codable {
    var date: Date
    var cardsStudied: Int
    var newCardsStudied: Int
    var correctCount: Int
    var incorrectCount: Int
    var totalTimeSeconds: Int
    
    init() {
        self.date = Date()
        self.cardsStudied = 0
        self.newCardsStudied = 0
        self.correctCount = 0
        self.incorrectCount = 0
        self.totalTimeSeconds = 0
    }
    
    var accuracy: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
}
