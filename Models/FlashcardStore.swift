import Foundation

class FlashcardStore: ObservableObject {
    @Published var decks: [FlashcardDeck] = []
    @Published var selectedDeckId: UUID?
    
    private let saveKey = "SavedFlashcardDecks"
    
    init() {
        loadDecks()
        if decks.isEmpty {
            let sampleDeck = FlashcardDeck(
                name: "HSK 1 Basics",
                cards: [
                    Flashcard(term: "你", definition: "you"),
                    Flashcard(term: "好", definition: "good"),
                    Flashcard(term: "我", definition: "I, me"),
                    Flashcard(term: "是", definition: "to be"),
                    Flashcard(term: "的", definition: "possessive particle"),
                    Flashcard(term: "人", definition: "person"),
                    Flashcard(term: "大", definition: "big"),
                    Flashcard(term: "小", definition: "small")
                ]
            )
            decks.append(sampleDeck)
            selectedDeckId = sampleDeck.id
            saveDecks()
        } else {
            selectedDeckId = decks.first?.id
        }
    }
    
    var selectedDeck: FlashcardDeck? {
        decks.first { $0.id == selectedDeckId }
    }
    
    func addDeck(name: String) {
        let deck = FlashcardDeck(name: name)
        decks.append(deck)
        saveDecks()
    }
    
    func deleteDeck(at offsets: IndexSet) {
        decks.remove(atOffsets: offsets)
        if selectedDeckId != nil && !decks.contains(where: { $0.id == selectedDeckId }) {
            selectedDeckId = decks.first?.id
        }
        saveDecks()
    }
    
    func addCard(toDeckId deckId: UUID, term: String, definition: String) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            let card = Flashcard(term: term, definition: definition)
            decks[index].cards.append(card)
            saveDecks()
        }
    }
    
    func deleteCard(fromDeckId deckId: UUID, at offsets: IndexSet) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].cards.remove(atOffsets: offsets)
            saveDecks()
        }
    }
    
    private func saveDecks() {
        if let encoded = try? JSONEncoder().encode(decks) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadDecks() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([FlashcardDeck].self, from: data) {
            decks = decoded
        }
    }
}
