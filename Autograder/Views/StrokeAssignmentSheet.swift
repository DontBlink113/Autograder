import SwiftUI
import PencilKit

struct StrokeAssignmentSheet: View {
    let strokes: [PKStroke]
    let character: String
    let definition: String
    let canvasSize: CGFloat
    let onSave: (ValidationDataPoint, String) -> Void
    let onCancel: () -> Void
    
    @StateObject private var manager = ValidationDatasetManager.shared
    @State private var strokeAssignments: [Int?]
    @State private var selectedDatasetName: String = ""
    @State private var newDatasetName: String = ""
    @State private var isCreatingNewDataset: Bool = false
    @State private var entryName: String = ""
    @State private var selectedUserStrokeIndex: Int? = nil
    
    private let sampler = StrokeSampler(pointsPerStroke: 50)
    
    private var referenceStrokeCount: Int {
        GraphicsLoader.shared.getStrokeCount(for: character)
    }
    
    init(strokes: [PKStroke], character: String, definition: String, canvasSize: CGFloat, onSave: @escaping (ValidationDataPoint, String) -> Void, onCancel: @escaping () -> Void) {
        self.strokes = strokes
        self.character = character
        self.definition = definition
        self.canvasSize = canvasSize
        self.onSave = onSave
        self.onCancel = onCancel
        _strokeAssignments = State(initialValue: Array(repeating: nil, count: strokes.count))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Character header
                    HStack {
                        Text(character)
                            .font(.system(size: 64))
                        VStack(alignment: .leading) {
                            Text("Add to Validation Dataset")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(strokes.count) strokes drawn • \(referenceStrokeCount) reference strokes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Dataset selection
                    datasetSelectionSection
                    
                    // Entry name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Name")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        TextField("e.g., 'Correct strokes in order'", text: $entryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        if entryName.isEmpty {
                            Text("Required")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Stroke assignment section
                    strokeAssignmentSection
                    
                    // Save button
                    Button(action: saveDataPoint) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save to Validation Dataset")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add to Validation Dataset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
    
    private var canSave: Bool {
        let hasDataset = !selectedDatasetName.isEmpty || !newDatasetName.isEmpty
        let hasEntryName = !entryName.isEmpty
        return hasDataset && hasEntryName
    }
    
    private var datasetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save to Dataset")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if manager.datasets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No datasets yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("New dataset name", text: $newDatasetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            } else {
                Picker("", selection: $isCreatingNewDataset) {
                    Text("Existing").tag(false)
                    Text("Create New").tag(true)
                }
                .pickerStyle(.segmented)
                
                if isCreatingNewDataset {
                    TextField("New dataset name", text: $newDatasetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Picker("Select Dataset", selection: $selectedDatasetName) {
                        Text("Select...").tag("")
                        ForEach(manager.datasetNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var strokeAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assign Each Stroke")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Tap a stroke, then select which reference stroke it should match (or 'Extra Stroke')")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // User strokes grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Strokes")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(0..<strokes.count, id: \.self) { index in
                        UserStrokeCellPK(
                            stroke: strokes[index],
                            index: index,
                            assignment: strokeAssignments[index],
                            isSelected: selectedUserStrokeIndex == index,
                            onTap: { selectedUserStrokeIndex = index }
                        )
                    }
                }
            }
            
            // Reference stroke assignment (when a user stroke is selected)
            if let selectedIndex = selectedUserStrokeIndex {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Assign Stroke \(selectedIndex + 1) to:")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Button("Extra Stroke") {
                            strokeAssignments[selectedIndex] = nil
                            advanceToNextUnassigned(from: selectedIndex)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Reference stroke buttons (based on graphics.txt)
                    if referenceStrokeCount > 0 {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 8) {
                            ForEach(0..<referenceStrokeCount, id: \.self) { refIndex in
                                Button(action: {
                                    strokeAssignments[selectedIndex] = refIndex
                                    advanceToNextUnassigned(from: selectedIndex)
                                }) {
                                    Text("Ref \(refIndex + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(strokeAssignments.contains(refIndex) ? .orange : .blue)
                                        .frame(width: 50, height: 40)
                                        .background(strokeAssignments.contains(refIndex) ? Color.orange.opacity(0.2) : Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    } else {
                        Text("Character not found in graphics.txt")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Assignment summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Assignment Summary")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                
                ForEach(0..<strokes.count, id: \.self) { index in
                    HStack {
                        Text("Stroke \(index + 1)")
                            .font(.caption)
                        Spacer()
                        if let refIndex = strokeAssignments[index] {
                            Text("→ Ref \(refIndex + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        } else {
                            Text("→ Extra")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground).opacity(0.5))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func advanceToNextUnassigned(from currentIndex: Int) {
        if let nextUnassigned = (0..<strokes.count).first(where: { strokeAssignments[$0] == nil && $0 != currentIndex }) {
            selectedUserStrokeIndex = nextUnassigned
        } else {
            selectedUserStrokeIndex = nil
        }
    }
    
    private func saveDataPoint() {
        // Convert strokes to point data
        let strokeData: [[PointData]] = strokes.map { stroke in
            let sampledPoints = sampler.samplePoints(from: stroke.path, startIndex: 0, endIndex: stroke.path.count - 1)
            return sampledPoints.map { PointData(x: $0.x, y: $0.y) }
        }
        
        let dataPoint = ValidationDataPoint(
            character: character,
            definition: definition,
            strokeData: strokeData,
            expectedMatchIndices: strokeAssignments,
            entryName: entryName
        )
        
        let datasetName = isCreatingNewDataset || manager.datasets.isEmpty ? newDatasetName : selectedDatasetName
        
        onSave(dataPoint, datasetName)
    }
}

struct UserStrokeCellPK: View {
    let stroke: PKStroke
    let index: Int
    let assignment: Int?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Color.white
                    StrokePreviewPK(stroke: stroke)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                
                Text("\(index + 1)")
                    .font(.caption2.bold())
                    .foregroundColor(.primary)
                
                if let refIdx = assignment {
                    Text("→ \(refIdx + 1)")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StrokePreviewPK: View {
    let stroke: PKStroke
    
    var body: some View {
        Canvas { context, size in
            guard stroke.path.count > 0 else { return }
            
            let points = (0..<stroke.path.count).map { stroke.path[$0].location }
            guard !points.isEmpty else { return }
            
            let minX = points.map { $0.x }.min() ?? 0
            let maxX = points.map { $0.x }.max() ?? 1
            let minY = points.map { $0.y }.min() ?? 0
            let maxY = points.map { $0.y }.max() ?? 1
            
            let width = max(maxX - minX, 1)
            let height = max(maxY - minY, 1)
            let scale = min((size.width - 8) / width, (size.height - 8) / height)
            
            let offsetX = (size.width - width * scale) / 2 - minX * scale
            let offsetY = (size.height - height * scale) / 2 - minY * scale
            
            var path = Path()
            for (i, point) in points.enumerated() {
                let scaledPoint = CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
                if i == 0 {
                    path.move(to: scaledPoint)
                } else {
                    path.addLine(to: scaledPoint)
                }
            }
            
            context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
