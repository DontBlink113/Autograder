import Foundation

class PracticeStats: ObservableObject {
    static let shared = PracticeStats()
    
    @Published var currentStreak: Int = 0
    @Published var questionsAnswered: Int = 0
    
    private let streakKey = "CurrentStreak"
    private let questionsKey = "QuestionsAnswered"
    
    private init() {
        loadStats()
    }
    
    func recordAnswer(wasCorrect: Bool) {
        questionsAnswered += 1
        
        if wasCorrect {
            currentStreak += 1
        } else {
            currentStreak = 0
        }
        
        saveStats()
    }
    
    func overrideAsCorrect() {
        // Called when user says "I was correct" - restore streak
        currentStreak += 1
        saveStats()
    }
    
    func resetStreak() {
        currentStreak = 0
        saveStats()
    }
    
    func resetAll() {
        currentStreak = 0
        questionsAnswered = 0
        saveStats()
    }
    
    private func saveStats() {
        UserDefaults.standard.set(currentStreak, forKey: streakKey)
        UserDefaults.standard.set(questionsAnswered, forKey: questionsKey)
    }
    
    private func loadStats() {
        currentStreak = UserDefaults.standard.integer(forKey: streakKey)
        questionsAnswered = UserDefaults.standard.integer(forKey: questionsKey)
    }
}
