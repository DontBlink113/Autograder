import Foundation

struct ChatGPTSentenceResponse: Codable {
    let chinese: String
    let english: String
}

class ChatGPTAPI {
    static let shared = ChatGPTAPI()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "ChatAPIKey") as? String
    }
    
    private init() {}
    
    func generateSentence(activeCharacters: String? = nil, completion: @escaping (Result<ChatGPTSentenceResponse, Error>) -> Void) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(ChatGPTError.missingAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(ChatGPTError.invalidURL))
            return
        }
        
        // Build prompt with active characters constraint
        var prompt = """
        Generate a random simple Chinese sentence that is 10 characters or fewer. 
        Return ONLY a JSON object with two fields:
        - "chinese": the Chinese sentence (no punctuation, just characters)
        - "english": the English translation
        """
        
        // If we have active characters, strongly encourage using them
        if let chars = activeCharacters, !chars.isEmpty {
            let uniqueChars = Array(Set(chars)).map { String($0) }.joined(separator: ", ")
            
            // Get beta-weighted priority characters
            let betaStore = CharacterBetaStore.shared
            let stats = betaStore.getActiveCharacterStats(activeCharacters: chars)
            
            // Prioritize weak characters (E < 0.33) in the prompt
            let weakChars = stats.filter { $0.expectedValue < 0.33 }.map { $0.character }
            let mediumChars = stats.filter { $0.expectedValue >= 0.33 && $0.expectedValue < 0.66 }.map { $0.character }
            
            prompt += "\n\nIMPORTANT: You MUST only use characters from this set: [\(uniqueChars)]"
            
            if !weakChars.isEmpty {
                prompt += "\n\nSTRONGLY PRIORITIZE using these characters (the student needs more practice): [\(weakChars.joined(separator: ", "))]"
            }
            if !mediumChars.isEmpty {
                prompt += "\n\nAlso try to include some of these characters: [\(mediumChars.joined(separator: ", "))]"
            }
        }
        
        prompt += """
        
        
        Example response:
        {"chinese": "我想吃苹果", "english": "I want to eat an apple"}
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a Chinese language learning assistant. Always respond with valid JSON only, no markdown or extra text. When given a set of allowed characters, you MUST only use characters from that set."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8,
            "max_tokens": 100
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(ChatGPTError.noData))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                guard let choices = json?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(ChatGPTError.invalidResponse))
                    return
                }
                
                // Parse the JSON content from GPT
                var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove markdown code blocks if present
                if cleanedContent.hasPrefix("```json") {
                    cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
                }
                if cleanedContent.hasPrefix("```") {
                    cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
                }
                cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
                cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let contentData = cleanedContent.data(using: .utf8) else {
                    print("ChatGPT: Failed to convert content to data: \(cleanedContent)")
                    completion(.failure(ChatGPTError.invalidResponse))
                    return
                }
                
                let sentenceResponse = try JSONDecoder().decode(ChatGPTSentenceResponse.self, from: contentData)
                completion(.success(sentenceResponse))
                
            } catch {
                print("ChatGPT parse error: \(error)")
                if let str = String(data: data, encoding: .utf8) {
                    print("Response: \(str)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    enum ChatGPTError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case noData
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "OpenAI API key not configured"
            case .invalidURL: return "Invalid API URL"
            case .noData: return "No data received"
            case .invalidResponse: return "Invalid response format"
            }
        }
    }
}
