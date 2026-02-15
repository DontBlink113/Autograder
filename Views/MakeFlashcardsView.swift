import SwiftUI

struct MakeFlashcardsView: View {
    @EnvironmentObject var store: FlashcardStore
    @State private var showingAddCardSheet = false
    @State private var showingAddDeckSheet = false
    @State private var selectedDeckId: UUID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        List {
            if store.decks.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Decks Yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap the + button to create your first deck")
                    )
                }
            } else {
                ForEach(store.decks) { deck in
                    Section(header: Text(deck.name)) {
                        ForEach(deck.cards) { card in
                            FlashcardRowView(flashcard: card)
                        }
                        .onDelete { offsets in
                            store.deleteCard(fromDeckId: deck.id, at: offsets)
                        }
                        
                        Button(action: {
                            selectedDeckId = deck.id
                            showingAddCardSheet = true
                        }) {
                            Label("Add Card", systemImage: "plus.circle")
                        }
                    }
                }
                .onDelete(perform: store.deleteDeck)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Flashcards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAddDeckSheet = true }) {
                        Label("New Deck", systemImage: "folder.badge.plus")
                    }
                    
                    if !store.decks.isEmpty {
                        Menu("Add Card to...") {
                            ForEach(store.decks) { deck in
                                Button(deck.name) {
                                    selectedDeckId = deck.id
                                    showingAddCardSheet = true
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCardSheet) {
            if let deckId = selectedDeckId {
                AddFlashcardView(deckId: deckId)
            }
        }
        .sheet(isPresented: $showingAddDeckSheet) {
            AddDeckView()
        }
    }
}

struct FlashcardRowView: View {
    let flashcard: Flashcard
    
    var body: some View {
        HStack(spacing: 12) {
            Text(flashcard.term)
                .font(.system(size: 28))
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(flashcard.term)
                    .font(.headline)
                
                Text(flashcard.definition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddFlashcardView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let deckId: UUID
    
    @State private var term = ""
    @State private var definition = ""
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        NavigationStack {
            Form {
                Section("Chinese Character") {
                    TextField("Enter character (e.g. 你)", text: $term)
                        .font(.system(size: 32))
                }
                
                Section("Definition") {
                    TextField("Enter definition (e.g. you)", text: $definition, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .frame(maxWidth: isIPad ? 600 : .infinity)
            .navigationTitle("New Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addCard(toDeckId: deckId, term: term, definition: definition)
                        dismiss()
                    }
                    .disabled(term.isEmpty || definition.isEmpty)
                }
            }
        }
        .presentationDetents(isIPad ? [.large] : [.medium, .large])
    }
}

struct AddDeckView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var name = ""
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        NavigationStack {
            Form {
                Section("Deck Name") {
                    TextField("Enter deck name", text: $name)
                }
            }
            .frame(maxWidth: isIPad ? 600 : .infinity)
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.addDeck(name: name)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents(isIPad ? [.large] : [.medium])
    }
}

#Preview {
    NavigationStack {
        MakeFlashcardsView()
            .environmentObject(FlashcardStore())
    }
}
