import Foundation
import PencilKit

class DigitalInkRecognizer {
    static let shared = DigitalInkRecognizer()
    
    // HanziLookup API endpoint on Railway
    private let apiURL = "https://walking-chinese-production.up.railway.app/recognize"
    
    private init() {}
    
    func recognize(strokes: [PKStroke], allowedCharacters: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard !strokes.isEmpty else {
            completion(.failure(RecognitionError.noResults))
            return
        }
        
        // Convert PKStrokes to API format: [[[x,y], [x,y], ...], ...]
        var strokesArray: [[[Double]]] = []
        
        for pkStroke in strokes {
            var points: [[Double]] = []
            for i in 0..<pkStroke.path.count {
                let point = pkStroke.path[i]
                points.append([Double(point.location.x), Double(point.location.y)])
            }
            if !points.isEmpty {
                strokesArray.append(points)
            }
        }
        
        // Build request
        guard let url = URL(string: apiURL) else {
            completion(.failure(RecognitionError.recognitionFailed))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "strokes": strokesArray,
            "count": 5,
            "dataset": "mmah"
        ]
        
        // Add allowed characters constraint if provided
        if let allowed = allowedCharacters, !allowed.isEmpty {
            body["allowedCharacters"] = allowed
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(RecognitionError.recognitionFailed))
            return
        }
        
        // Make API call
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("HanziLookup API error: \(error)")
                completion(.failure(RecognitionError.recognitionFailed))
                return
            }
            
            guard let data = data else {
                completion(.failure(RecognitionError.noResults))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let matches = json["matches"] as? [[String: Any]],
                   let firstMatch = matches.first,
                   let character = firstMatch["character"] as? String {
                    completion(.success(character))
                } else {
                    completion(.failure(RecognitionError.noResults))
                }
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(RecognitionError.recognitionFailed))
            }
        }.resume()
    }
    
    var isReady: Bool {
        return true  // API is always ready
    }
    
    enum RecognitionError: Error, LocalizedError {
        case modelNotReady
        case recognitionFailed
        case noResults
        
        var errorDescription: String? {
            switch self {
            case .modelNotReady: return "Recognition service not ready"
            case .recognitionFailed: return "Recognition failed"
            case .noResults: return "No recognition results"
            }
        }
    }
}
