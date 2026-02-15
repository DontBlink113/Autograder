import SwiftUI

struct ValidationDatasetView: View {
    @StateObject private var manager = ValidationDatasetManager.shared
    @State private var showShareSheet: Bool = false
    @State private var exportFileURL: URL? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var datasetToDelete: ValidationDataset? = nil
    @State private var expandedDatasetId: UUID? = nil
    
    var body: some View {
        List {
            if manager.datasets.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No Validation Data Yet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Add entries during flashcard practice by tapping 'Add to Validation Dataset' after checking your answer.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                }
            } else {
                Section(header: Text("Summary")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(manager.datasets.count)")
                                .font(.title.bold())
                                .foregroundColor(.blue)
                            Text("Datasets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(manager.totalDataPointCount)")
                                .font(.title.bold())
                                .foregroundColor(.blue)
                            Text("Total Entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Validation Datasets")) {
                    ForEach(manager.datasets) { dataset in
                        DatasetRowView(
                            dataset: dataset,
                            isExpanded: expandedDatasetId == dataset.id,
                            onToggleExpand: {
                                withAnimation {
                                    expandedDatasetId = expandedDatasetId == dataset.id ? nil : dataset.id
                                }
                            },
                            onExport: {
                                if let json = manager.exportDataset(dataset) {
                                    let fileName = "\(dataset.name.replacingOccurrences(of: " ", with: "_")).json"
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                                    try? json.write(to: tempURL, atomically: true, encoding: .utf8)
                                    exportFileURL = tempURL
                                    showShareSheet = true
                                }
                            },
                            onDelete: {
                                datasetToDelete = dataset
                                showDeleteConfirmation = true
                            },
                            onDeleteDataPoint: { dataPointId in
                                manager.deleteDataPoint(dataPointId: dataPointId, fromDatasetId: dataset.id)
                            }
                        )
                    }
                }
                
                Section {
                    Button(action: exportAllDatasets) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All Datasets")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Validation Dataset")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportFileURL {
                ValidationShareSheet(activityItems: [url])
            }
        }
        .alert("Delete Dataset?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { datasetToDelete = nil }
            Button("Delete", role: .destructive) {
                if let dataset = datasetToDelete,
                   let index = manager.datasets.firstIndex(where: { $0.id == dataset.id }) {
                    manager.deleteDataset(at: index)
                }
                datasetToDelete = nil
            }
        } message: {
            Text("This will permanently delete '\(datasetToDelete?.name ?? "")' and all its entries.")
        }
    }
    
    private func exportAllDatasets() {
        if let json = manager.exportAllDatasets() {
            let fileName = "all_validation_datasets.json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? json.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showShareSheet = true
        }
    }
}

struct DatasetRowView: View {
    let dataset: ValidationDataset
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    let onDeleteDataPoint: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpand) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dataset.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(dataset.dataPoints.count) entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider().padding(.vertical, 8)
                
                HStack(spacing: 12) {
                    Button(action: onExport) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Button(action: onDelete) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(.bottom, 8)
                
                ForEach(dataset.dataPoints) { dataPoint in
                    DataPointRowView(dataPoint: dataPoint, onDelete: { onDeleteDataPoint(dataPoint.id) })
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct DataPointRowView: View {
    let dataPoint: ValidationDataPoint
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(dataPoint.character)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(dataPoint.entryName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(dataPoint.strokeCount) strokes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

struct ValidationShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
