import Foundation

struct Flashcard: Identifiable, Codable, Hashable {
    let id: UUID
    var term: String
    var definition: String
    var createdAt: Date
    
    init(id: UUID = UUID(), term: String, definition: String, createdAt: Date = Date()) {
        self.id = id
        self.term = term
        self.definition = definition
        self.createdAt = createdAt
    }
}

struct FlashcardDeck: Identifiable, Codable {
    let id: UUID
    var name: String
    var cards: [Flashcard]
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, cards: [Flashcard] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.cards = cards
        self.createdAt = createdAt
    }
}
