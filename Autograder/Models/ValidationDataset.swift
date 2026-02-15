import Foundation

// MARK: - Validation Data Point

struct ValidationDataPoint: Identifiable, Codable {
    let id: UUID
    let character: String
    let definition: String
    let strokeData: [[PointData]]  // Array of strokes, each stroke is array of points
    let expectedMatchIndices: [Int?]  // Expected reference stroke index for each user stroke (nil = extra/no match)
    let entryName: String
    let timestamp: Date
    
    init(id: UUID = UUID(), character: String, definition: String, strokeData: [[PointData]], expectedMatchIndices: [Int?], entryName: String, timestamp: Date = Date()) {
        self.id = id
        self.character = character
        self.definition = definition
        self.strokeData = strokeData
        self.expectedMatchIndices = expectedMatchIndices
        self.entryName = entryName
        self.timestamp = timestamp
    }
    
    var strokeCount: Int {
        strokeData.count
    }
}

struct PointData: Codable {
    let x: Double
    let y: Double
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    init(from cgPoint: CGPoint) {
        self.x = cgPoint.x
        self.y = cgPoint.y
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Validation Dataset

struct ValidationDataset: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let dataPoints: [ValidationDataPoint]
    
    init(id: UUID = UUID(), name: String, description: String = "", dataPoints: [ValidationDataPoint] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.dataPoints = dataPoints
    }
}

// MARK: - Validation Dataset Manager

class ValidationDatasetManager: ObservableObject {
    static let shared = ValidationDatasetManager()
    
    @Published var datasets: [ValidationDataset] = []
    
    private let userDefaultsKey = "validationDatasets"
    
    init() {
        loadDatasets()
    }
    
    func loadDatasets() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([ValidationDataset].self, from: data) else {
            datasets = []
            return
        }
        datasets = decoded
    }
    
    func saveDatasets() {
        guard let data = try? JSONEncoder().encode(datasets) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    func addDataPoint(_ dataPoint: ValidationDataPoint, toDatasetNamed name: String) {
        if let index = datasets.firstIndex(where: { $0.name == name }) {
            var dataset = datasets[index]
            var newDataPoints = dataset.dataPoints
            newDataPoints.append(dataPoint)
            datasets[index] = ValidationDataset(
                id: dataset.id,
                name: dataset.name,
                description: dataset.description,
                dataPoints: newDataPoints
            )
        } else {
            let newDataset = ValidationDataset(
                name: name,
                description: "Custom validation dataset",
                dataPoints: [dataPoint]
            )
            datasets.append(newDataset)
        }
        saveDatasets()
    }
    
    func deleteDataset(at index: Int) {
        guard index < datasets.count else { return }
        datasets.remove(at: index)
        saveDatasets()
    }
    
    func deleteDataPoint(dataPointId: UUID, fromDatasetId: UUID) {
        guard let datasetIndex = datasets.firstIndex(where: { $0.id == fromDatasetId }) else { return }
        let dataset = datasets[datasetIndex]
        let newDataPoints = dataset.dataPoints.filter { $0.id != dataPointId }
        datasets[datasetIndex] = ValidationDataset(
            id: dataset.id,
            name: dataset.name,
            description: dataset.description,
            dataPoints: newDataPoints
        )
        saveDatasets()
    }
    
    func exportDataset(_ dataset: ValidationDataset) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(dataset) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func exportAllDatasets() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(datasets) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    var datasetNames: [String] {
        datasets.map { $0.name }
    }
    
    var totalDataPointCount: Int {
        datasets.reduce(0) { $0 + $1.dataPoints.count }
    }
}
