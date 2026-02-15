import Foundation

struct AutograderRequest: Codable {
    let character: String
    let strokes: [StrokeInput]
    
    struct StrokeInput: Codable {
        let points: [PointInput]
    }
    
    struct PointInput: Codable {
        let x: Double
        let y: Double
    }
}

struct AutograderResponse: Codable {
    let character: String
    let accuracy: Double
    let mapping: [Int]
    let errors: [StrokeError]
    let fitness: Double
    
    struct StrokeError: Codable {
        let type: String
        let description: String
        let written_indices: [Int]?
        let reference_index: Int?
    }
}

enum StrokeStatus {
    case correct          // Mapped to correct reference stroke in order
    case wrongOrder       // Mapped but out of order
    case incorrect        // No match (mapping = 0)
}

class AutograderAPI {
    static let shared = AutograderAPI()
    
    private let baseURL = "https://autograder-production-2d31.up.railway.app"
    
    private init() {}
    
    func classifyStrokes(character: String, strokes: [[CGPoint]], completion: @escaping (Result<AutograderResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/match") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        let strokeInputs = strokes.map { points in
            AutograderRequest.StrokeInput(
                points: points.map { AutograderRequest.PointInput(x: $0.x, y: $0.y) }
            )
        }
        
        let request = AutograderRequest(character: character, strokes: strokeInputs)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(AutograderResponse.self, from: data)
                completion(.success(response))
            } catch {
                print("Decode error: \(error)")
                if let str = String(data: data, encoding: .utf8) {
                    print("Response: \(str)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Determine stroke status based on mapping and errors
    static func getStrokeStatuses(from response: AutograderResponse) -> [StrokeStatus] {
        var statuses: [StrokeStatus] = []
        
        // Get indices that have ORDER errors
        var orderErrorIndices: Set<Int> = []
        for error in response.errors {
            if error.type == "ORDER", let indices = error.written_indices {
                for idx in indices {
                    orderErrorIndices.insert(idx)
                }
            }
        }
        
        for (index, mappedRef) in response.mapping.enumerated() {
            if mappedRef == 0 {
                // No match
                statuses.append(.incorrect)
            } else if orderErrorIndices.contains(index + 1) {
                // Has order error (written_indices are 1-indexed)
                statuses.append(.wrongOrder)
            } else {
                // Correct
                statuses.append(.correct)
            }
        }
        
        return statuses
    }
    
    enum APIError: Error {
        case invalidURL
        case noData
    }
}
