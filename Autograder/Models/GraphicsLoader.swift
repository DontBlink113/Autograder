import Foundation

struct ReferenceCharacter: Codable {
    let character: String
    let strokes: [String]  // SVG paths
    let medians: [[[Double]]]  // Median points for each stroke
    
    var strokeCount: Int {
        strokes.count
    }
}

class GraphicsLoader {
    static let shared = GraphicsLoader()
    
    private var characterMap: [String: ReferenceCharacter] = [:]
    private var isLoaded = false
    
    private init() {
        loadGraphicsData()
    }
    
    func loadGraphicsData() {
        guard !isLoaded else { return }
        
        guard let url = Bundle.main.url(forResource: "graphics", withExtension: "txt") else {
            print("Error: graphics.txt not found")
            return
        }
        
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Error: Could not read graphics.txt")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            guard let data = line.data(using: .utf8) else { continue }
            
            do {
                let refChar = try JSONDecoder().decode(ReferenceCharacter.self, from: data)
                characterMap[refChar.character] = refChar
            } catch {
                continue
            }
        }
        
        isLoaded = true
        print("Loaded \(characterMap.count) characters from graphics.txt")
    }
    
    func getCharacter(_ char: String) -> ReferenceCharacter? {
        return characterMap[char]
    }
    
    func getStrokeCount(for char: String) -> Int {
        return characterMap[char]?.strokeCount ?? 0
    }
    
    func hasCharacter(_ char: String) -> Bool {
        return characterMap[char] != nil
    }
}
