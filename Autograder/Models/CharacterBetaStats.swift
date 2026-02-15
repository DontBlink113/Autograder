import Foundation

enum UrgencyTier: Int, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    
    static func < (lhs: UrgencyTier, rhs: UrgencyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CharacterBetaStats: Codable, Identifiable {
    var id: String { character }
    let character: String
    var alpha: Double  // successes + 1 (prior)
    var beta: Double   // failures + 1 (prior)
    var lastSeenDate: Date?
    var lastSessionId: Int
    
    init(character: String, alpha: Double = 1.0, beta: Double = 1.0, lastSeenDate: Date? = nil, lastSessionId: Int = 0) {
        self.character = character
        self.alpha = alpha
        self.beta = beta
        self.lastSeenDate = lastSeenDate
        self.lastSessionId = lastSessionId
    }
    
    var expectedValue: Double {
        alpha / (alpha + beta)
    }
    
    var variance: Double {
        (alpha * beta) / ((alpha + beta) * (alpha + beta) * (alpha + beta + 1))
    }
    
    var totalAttempts: Int {
        Int(alpha + beta - 2)  // Subtract 2 for the prior (1,1)
    }
    
    var successes: Int {
        Int(alpha - 1)
    }
    
    var failures: Int {
        Int(beta - 1)
    }
    
    mutating func recordSuccess() {
        alpha += 1
    }
    
    mutating func recordFailure() {
        beta += 1
    }
    
    mutating func markSeen(sessionId: Int) {
        lastSeenDate = Date()
        lastSessionId = sessionId
    }
    
    var daysSinceLastSeen: Int {
        guard let lastSeen = lastSeenDate else { return Int.max }
        return Calendar.current.dateComponents([.day], from: lastSeen, to: Date()).day ?? Int.max
    }
    
    func urgencyTier(currentSessionId: Int, sessionStartTime: Date) -> UrgencyTier {
        let ev = expectedValue
        
        if ev < 0.33 {
            // Weak: must see at least once per 30-min session
            if lastSessionId < currentSessionId {
                return .high  // Not seen this session yet
            }
            // Check if seen in last 5 minutes of this session
            if let lastSeen = lastSeenDate, lastSeen >= sessionStartTime {
                let minutesSinceSeen = Date().timeIntervalSince(lastSeen) / 60
                return minutesSinceSeen > 5 ? .medium : .low
            }
            return .high
        } else if ev < 0.66 {
            // Medium: must see at least every 3rd session
            let sessionsSinceSeen = currentSessionId - lastSessionId
            if sessionsSinceSeen >= 3 {
                return .high
            } else if sessionsSinceSeen >= 1 {
                return .low
            }
            return .none
        } else {
            // Strong: won't see for at least 10 days
            if daysSinceLastSeen >= 10 {
                return .medium
            }
            return .none
        }
    }
    
    var logitBias: Int {
        let ev = expectedValue
        if ev < 0.33 {
            return 5  // Strong bias for weak characters
        } else if ev < 0.66 {
            return 3  // Medium bias
        } else {
            return 1  // Light bias for strong characters
        }
    }
}

class CharacterBetaStore: ObservableObject {
    static let shared = CharacterBetaStore()
    
    @Published var characterStats: [String: CharacterBetaStats] = [:]
    @Published var currentSessionId: Int = 0
    @Published var sessionStartTime: Date = Date()
    
    private let saveKey = "CharacterBetaStats"
    private let sessionIdKey = "CurrentSessionId"
    
    private init() {
        loadStats()
        currentSessionId = UserDefaults.standard.integer(forKey: sessionIdKey)
    }
    
    func startNewSession() {
        currentSessionId += 1
        sessionStartTime = Date()
        UserDefaults.standard.set(currentSessionId, forKey: sessionIdKey)
    }
    
    func getStats(for character: String) -> CharacterBetaStats {
        if let stats = characterStats[character] {
            return stats
        }
        // Create new stats with uniform prior Beta(1,1)
        let newStats = CharacterBetaStats(character: character)
        characterStats[character] = newStats
        saveStats()
        return newStats
    }
    
    func recordSuccess(for character: String) {
        if characterStats[character] == nil {
            characterStats[character] = CharacterBetaStats(character: character)
        }
        characterStats[character]?.recordSuccess()
        characterStats[character]?.markSeen(sessionId: currentSessionId)
        saveStats()
    }
    
    func recordFailure(for character: String) {
        if characterStats[character] == nil {
            characterStats[character] = CharacterBetaStats(character: character)
        }
        characterStats[character]?.recordFailure()
        characterStats[character]?.markSeen(sessionId: currentSessionId)
        saveStats()
    }
    
    func markCharacterSeen(_ character: String) {
        if characterStats[character] == nil {
            characterStats[character] = CharacterBetaStats(character: character)
        }
        characterStats[character]?.markSeen(sessionId: currentSessionId)
        saveStats()
    }
    
    func getActiveCharacterStats(activeCharacters: String) -> [CharacterBetaStats] {
        let uniqueChars = Set(activeCharacters)
        return uniqueChars.map { char in
            getStats(for: String(char))
        }.sorted { $0.expectedValue < $1.expectedValue }  // Sort by weakest first
    }
    
    // MARK: - Sampling for Active Mode
    
    func sampleCharacter(from activeCharacters: String) -> String? {
        let stats = getActiveCharacterStats(activeCharacters: activeCharacters)
        guard !stats.isEmpty else { return nil }
        
        // Build weighted pool based on urgency
        var weightedPool: [(character: String, weight: Double)] = []
        
        for stat in stats {
            let urgency = stat.urgencyTier(currentSessionId: currentSessionId, sessionStartTime: sessionStartTime)
            let weight: Double
            switch urgency {
            case .high: weight = 10.0
            case .medium: weight = 3.0
            case .low: weight = 1.0
            case .none: weight = 0.0
            }
            if weight > 0 {
                weightedPool.append((stat.character, weight))
            }
        }
        
        // If no urgent characters, include all with minimal weight
        if weightedPool.isEmpty {
            weightedPool = stats.map { ($0.character, 0.1) }
        }
        
        // Weighted random selection
        let totalWeight = weightedPool.reduce(0) { $0 + $1.weight }
        var random = Double.random(in: 0..<totalWeight)
        
        for (character, weight) in weightedPool {
            random -= weight
            if random <= 0 {
                return character
            }
        }
        
        return weightedPool.last?.character
    }
    
    func getStudyQueue(from activeCharacters: String, count: Int = 10) -> [String] {
        let stats = getActiveCharacterStats(activeCharacters: activeCharacters)
        guard !stats.isEmpty else { return [] }
        
        var queue: [String] = []
        var usedCharacters = Set<String>()
        
        // First, ensure all HIGH urgency characters are included
        for stat in stats {
            let urgency = stat.urgencyTier(currentSessionId: currentSessionId, sessionStartTime: sessionStartTime)
            if urgency == .high && !usedCharacters.contains(stat.character) {
                queue.append(stat.character)
                usedCharacters.insert(stat.character)
            }
        }
        
        // Fill remaining slots with weighted sampling
        while queue.count < count {
            if let sampled = sampleCharacter(from: activeCharacters) {
                if !usedCharacters.contains(sampled) {
                    queue.append(sampled)
                    usedCharacters.insert(sampled)
                } else if usedCharacters.count >= stats.count {
                    // All characters used, allow repeats
                    queue.append(sampled)
                }
            } else {
                break
            }
        }
        
        return queue.shuffled()
    }
    
    // MARK: - Logit Bias for LLM
    
    func getLogitBiasMap(for activeCharacters: String) -> [String: Int] {
        let stats = getActiveCharacterStats(activeCharacters: activeCharacters)
        var biasMap: [String: Int] = [:]
        
        for stat in stats {
            biasMap[stat.character] = stat.logitBias
        }
        
        return biasMap
    }
    
    func resetStats(for character: String) {
        characterStats[character] = CharacterBetaStats(character: character)
        saveStats()
    }
    
    func resetAllStats() {
        characterStats.removeAll()
        saveStats()
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(characterStats) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([String: CharacterBetaStats].self, from: data) {
            characterStats = decoded
        }
    }
}
