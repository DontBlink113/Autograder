import Foundation

class FlashcardStore: ObservableObject {
    @Published var decks: [FlashcardDeck] = []
    @Published var selectedDeckId: UUID?
    @Published var currentSessionStats: StudySessionStats = StudySessionStats()
    @Published var studyHistory: [StudySessionStats] = []
    @Published var singleActiveCharacters: String = ""  // Individual active characters not in any deck
    
    private let saveKey = "SavedFlashcardDecks"
    private let historyKey = "StudyHistory"
    private let singleCharsKey = "SingleActiveCharacters"
    
    private let activeCardsDeckName = "Active Cards"
    
    init() {
        loadDecks()
        loadHistory()
        loadSingleActiveCharacters()
        ensureActiveCardsDeck()
        if selectedDeckId == nil {
            selectedDeckId = decks.first?.id
        }
    }
    
    private func ensureActiveCardsDeck() {
        // Always ensure "Active Cards" deck exists and is first
        if !decks.contains(where: { $0.name == activeCardsDeckName }) {
            let activeCardsDeck = FlashcardDeck(
                name: activeCardsDeckName,
                cards: [
                    Flashcard(term: "我", definition: "I, me"),
                    Flashcard(term: "你", definition: "you"),
                    Flashcard(term: "他", definition: "he, him"),
                    Flashcard(term: "她", definition: "she, her"),
                    Flashcard(term: "吃", definition: "to eat"),
                    Flashcard(term: "好", definition: "good"),
                    Flashcard(term: "吗", definition: "question particle"),
                    Flashcard(term: "喝", definition: "to drink"),
                    Flashcard(term: "饭", definition: "food, rice"),
                    Flashcard(term: "水", definition: "water")
                ],
                description: "Your current study cards"
            )
            decks.insert(activeCardsDeck, at: 0)
            selectedDeckId = activeCardsDeck.id
            saveDecks()
        } else {
            // Move Active Cards to front if it exists but isn't first
            if let index = decks.firstIndex(where: { $0.name == activeCardsDeckName }), index != 0 {
                let deck = decks.remove(at: index)
                decks.insert(deck, at: 0)
                saveDecks()
            }
        }
    }
    
    var selectedDeck: FlashcardDeck? {
        decks.first { $0.id == selectedDeckId }
    }
    
    // MARK: - Deck Management
    
    func addDeck(name: String, description: String = "") {
        let deck = FlashcardDeck(name: name, description: description)
        decks.append(deck)
        saveDecks()
    }
    
    func updateDeck(deckId: UUID, name: String? = nil, description: String? = nil, dailyNewLimit: Int? = nil, dailyReviewLimit: Int? = nil) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            if let name = name { decks[index].name = name }
            if let description = description { decks[index].description = description }
            if let limit = dailyNewLimit { decks[index].dailyNewCardLimit = limit }
            if let limit = dailyReviewLimit { decks[index].dailyReviewLimit = limit }
            saveDecks()
        }
    }
    
    func deleteDeck(at offsets: IndexSet) {
        decks.remove(atOffsets: offsets)
        if selectedDeckId != nil && !decks.contains(where: { $0.id == selectedDeckId }) {
            selectedDeckId = decks.first?.id
        }
        saveDecks()
    }
    
    func deleteDeck(deckId: UUID) {
        decks.removeAll { $0.id == deckId }
        if selectedDeckId == deckId {
            selectedDeckId = decks.first?.id
        }
        saveDecks()
    }
    
    // MARK: - Card Management
    
    func addCard(toDeckId deckId: UUID, term: String, definition: String, tags: [String] = [], notes: String = "") {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            let card = Flashcard(term: term, definition: definition, tags: tags, notes: notes)
            decks[index].cards.append(card)
            saveDecks()
        }
    }
    
    func updateCard(deckId: UUID, cardId: UUID, term: String? = nil, definition: String? = nil, tags: [String]? = nil, notes: String? = nil) {
        if let deckIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cardIndex = decks[deckIndex].cards.firstIndex(where: { $0.id == cardId }) {
            if let term = term { decks[deckIndex].cards[cardIndex].term = term }
            if let definition = definition { decks[deckIndex].cards[cardIndex].definition = definition }
            if let tags = tags { decks[deckIndex].cards[cardIndex].tags = tags }
            if let notes = notes { decks[deckIndex].cards[cardIndex].notes = notes }
            saveDecks()
        }
    }
    
    func deleteCard(fromDeckId deckId: UUID, at offsets: IndexSet) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].cards.remove(atOffsets: offsets)
            saveDecks()
        }
    }
    
    func deleteCard(deckId: UUID, cardId: UUID) {
        if let deckIndex = decks.firstIndex(where: { $0.id == deckId }) {
            decks[deckIndex].cards.removeAll { $0.id == cardId }
            saveDecks()
        }
    }
    
    func moveCard(fromDeckId: UUID, cardId: UUID, toDeckId: UUID) {
        guard let fromIndex = decks.firstIndex(where: { $0.id == fromDeckId }),
              let toIndex = decks.firstIndex(where: { $0.id == toDeckId }),
              let cardIndex = decks[fromIndex].cards.firstIndex(where: { $0.id == cardId }) else { return }
        
        let card = decks[fromIndex].cards.remove(at: cardIndex)
        decks[toIndex].cards.append(card)
        saveDecks()
    }
    
    // MARK: - Spaced Repetition
    
    func reviewCard(deckId: UUID, cardId: UUID, quality: ReviewQuality) {
        if let deckIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cardIndex = decks[deckIndex].cards.firstIndex(where: { $0.id == cardId }) {
            
            let wasNew = decks[deckIndex].cards[cardIndex].isNew
            decks[deckIndex].cards[cardIndex].review(quality: quality)
            
            // Update session stats
            currentSessionStats.cardsStudied += 1
            if wasNew { currentSessionStats.newCardsStudied += 1 }
            if quality.rawValue >= 3 {
                currentSessionStats.correctCount += 1
            } else {
                currentSessionStats.incorrectCount += 1
            }
            
            saveDecks()
        }
    }
    
    func getStudyQueue(forDeckId deckId: UUID) -> [Flashcard] {
        guard let deck = decks.first(where: { $0.id == deckId }) else { return [] }
        return deck.getStudyQueue()
    }
    
    func resetCardProgress(deckId: UUID, cardId: UUID) {
        if let deckIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cardIndex = decks[deckIndex].cards.firstIndex(where: { $0.id == cardId }) {
            decks[deckIndex].cards[cardIndex].srsData = SpacedRepetitionData()
            saveDecks()
        }
    }
    
    func resetDeckProgress(deckId: UUID) {
        if let deckIndex = decks.firstIndex(where: { $0.id == deckId }) {
            for cardIndex in decks[deckIndex].cards.indices {
                decks[deckIndex].cards[cardIndex].srsData = SpacedRepetitionData()
            }
            saveDecks()
        }
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        // Save previous session if it has data
        if currentSessionStats.cardsStudied > 0 {
            studyHistory.append(currentSessionStats)
            saveHistory()
        }
        currentSessionStats = StudySessionStats()
    }
    
    func endSession() {
        if currentSessionStats.cardsStudied > 0 {
            studyHistory.append(currentSessionStats)
            saveHistory()
        }
        currentSessionStats = StudySessionStats()
    }
    
    // MARK: - Statistics
    
    var totalCardsAcrossDecks: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }
    
    var totalDueCards: Int {
        decks.reduce(0) { $0 + $1.dueCount }
    }
    
    var totalNewCards: Int {
        decks.reduce(0) { $0 + $1.newCount }
    }
    
    var overallAccuracy: Double {
        let allCards = decks.flatMap { $0.cards }.filter { $0.srsData.totalReviews > 0 }
        guard !allCards.isEmpty else { return 0 }
        let totalCorrect = allCards.reduce(0) { $0 + $1.srsData.correctReviews }
        let totalReviews = allCards.reduce(0) { $0 + $1.srsData.totalReviews }
        guard totalReviews > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalReviews)
    }
    
    var streakDays: Int {
        guard !studyHistory.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedHistory = studyHistory.sorted { $0.date > $1.date }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for session in sortedHistory {
            let sessionDate = calendar.startOfDay(for: session.date)
            if sessionDate == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if sessionDate < currentDate {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Active Characters
    
    // All characters from active decks + selected deck + single active characters
    var allActiveCharacters: String {
        var chars = Set<String>()
        
        // Add characters from active decks
        for deck in decks where deck.isActive {
            for card in deck.cards {
                chars.insert(card.term)
            }
        }
        
        // Also add characters from the currently selected deck (even if not marked active)
        if let selectedDeck = selectedDeck {
            for card in selectedDeck.cards {
                chars.insert(card.term)
            }
        }
        
        // Add single active characters
        for char in singleActiveCharacters {
            chars.insert(String(char))
        }
        
        return chars.joined()
    }
    
    // Active decks only
    var activeDecks: [FlashcardDeck] {
        decks.filter { $0.isActive }
    }
    
    // Get all cards from active decks combined
    func getActiveDecksStudyQueue() -> [Flashcard] {
        var allCards: [Flashcard] = []
        for deck in activeDecks {
            allCards.append(contentsOf: deck.cards)
        }
        // If no active decks, fall back to selected deck
        if allCards.isEmpty, let selectedDeck = selectedDeck {
            allCards = selectedDeck.cards
        }
        return allCards.shuffled()
    }
    
    func toggleDeckActive(deckId: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].isActive.toggle()
            saveDecks()
        }
    }
    
    func setDeckActive(deckId: UUID, isActive: Bool) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].isActive = isActive
            saveDecks()
        }
    }
    
    func addSingleActiveCharacter(_ char: String) {
        if !singleActiveCharacters.contains(char) {
            singleActiveCharacters += char
            saveSingleActiveCharacters()
        }
    }
    
    func removeSingleActiveCharacter(_ char: String) {
        singleActiveCharacters = singleActiveCharacters.replacingOccurrences(of: char, with: "")
        saveSingleActiveCharacters()
    }
    
    private func saveSingleActiveCharacters() {
        UserDefaults.standard.set(singleActiveCharacters, forKey: singleCharsKey)
    }
    
    private func loadSingleActiveCharacters() {
        singleActiveCharacters = UserDefaults.standard.string(forKey: singleCharsKey) ?? ""
    }
    
    func getWeeklyStats() -> [StudySessionStats] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return studyHistory.filter { $0.date >= weekAgo }
    }
    
    // MARK: - Persistence
    
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
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(studyHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([StudySessionStats].self, from: data) {
            studyHistory = decoded
        }
    }
    
    // MARK: - Import/Export
    
    func exportDeck(deckId: UUID) -> String? {
        guard let deck = decks.first(where: { $0.id == deckId }) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(deck) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func importDeck(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let deck = try? JSONDecoder().decode(FlashcardDeck.self, from: data) else {
            return false
        }
        // Create new deck with new ID to avoid conflicts
        var newDeck = deck
        newDeck = FlashcardDeck(name: deck.name, cards: deck.cards, description: deck.description)
        decks.append(newDeck)
        saveDecks()
        return true
    }
}
