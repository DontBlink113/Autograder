import SwiftUI

struct MakeFlashcardsView: View {
    @EnvironmentObject var store: FlashcardStore
    @State private var showingAddCardSheet = false
    @State private var showingAddDeckSheet = false
    @State private var showingEditDeckSheet = false
    @State private var showingEditCardSheet = false
    @State private var selectedDeckId: UUID?
    @State private var selectedCardId: UUID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            List {
                // Stats Summary
                if !store.decks.isEmpty {
                    Section {
                        HStack(spacing: 20) {
                            StatBadge(value: "\(store.totalCardsAcrossDecks)", label: "Cards", color: .blue)
                            StatBadge(value: "\(store.totalDueCards)", label: "Due", color: .orange)
                            StatBadge(value: "\(store.totalNewCards)", label: "New", color: .green)
                            if store.overallAccuracy > 0 {
                                StatBadge(value: "\(Int(store.overallAccuracy * 100))%", label: "Accuracy", color: .purple)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                
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
                        Section {
                            DeckHeaderView(deck: deck) {
                                selectedDeckId = deck.id
                                showingEditDeckSheet = true
                            }
                            
                            ForEach(deck.cards) { card in
                                FlashcardRowView(flashcard: card)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedDeckId = deck.id
                                        selectedCardId = card.id
                                        showingEditCardSheet = true
                                    }
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
                        } header: {
                            Text(deck.name)
                        }
                    }
                    .onDelete(perform: store.deleteDeck)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
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
        .sheet(isPresented: $showingEditDeckSheet) {
            if let deckId = selectedDeckId,
               let deck = store.decks.first(where: { $0.id == deckId }) {
                EditDeckView(deck: deck)
            }
        }
        .sheet(isPresented: $showingEditCardSheet) {
            if let deckId = selectedDeckId,
               let cardId = selectedCardId,
               let deck = store.decks.first(where: { $0.id == deckId }),
               let card = deck.cards.first(where: { $0.id == cardId }) {
                EditFlashcardView(deckId: deckId, card: card)
            }
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTheme.Typography.title2)
                .foregroundColor(color)
            Text(label)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.stone)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DeckHeaderView: View {
    @EnvironmentObject var store: FlashcardStore
    let deck: FlashcardDeck
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Active toggle
                    Button(action: {
                        store.toggleDeckActive(deckId: deck.id)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: deck.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(deck.isActive ? AppTheme.forestGreen : AppTheme.stone)
                            Text(deck.isActive ? "Active" : "Inactive")
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(deck.isActive ? AppTheme.forestGreen : AppTheme.stone)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if !deck.description.isEmpty {
                    Text(deck.description)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.stone)
                }
                HStack(spacing: 12) {
                    Label("\(deck.cards.count)", systemImage: "rectangle.stack")
                    Label("\(deck.dueCount) due", systemImage: "clock")
                        .foregroundColor(deck.dueCount > 0 ? AppTheme.amber : AppTheme.stone)
                    Label("\(deck.newCount) new", systemImage: "sparkles")
                        .foregroundColor(deck.newCount > 0 ? AppTheme.forestGreen : AppTheme.stone)
                }
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.stone)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "gearshape")
                    .foregroundColor(AppTheme.forestGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct FlashcardRowView: View {
    let flashcard: Flashcard
    
    var body: some View {
        HStack(spacing: 12) {
            Text(flashcard.term)
                .font(.system(size: 28))
                .foregroundColor(AppTheme.forestGreen)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(flashcard.definition)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    // SRS Status
                    if flashcard.isNew {
                        Text("NEW")
                            .font(AppTheme.Typography.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.forestGreen.opacity(0.15))
                            .foregroundColor(AppTheme.forestGreen)
                            .cornerRadius(AppTheme.Radius.sm)
                    } else if flashcard.isDue {
                        Text("DUE")
                            .font(AppTheme.Typography.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.amber.opacity(0.2))
                            .foregroundColor(AppTheme.amberDark)
                            .cornerRadius(AppTheme.Radius.sm)
                    } else {
                        Text("\(flashcard.srsData.interval)d")
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(AppTheme.stone)
                    }
                }
                
                // Progress indicator
                if flashcard.srsData.totalReviews > 0 {
                    HStack(spacing: 4) {
                        Text("\(flashcard.srsData.totalReviews) reviews")
                        Text("•")
                        Text("\(Int(flashcard.srsData.accuracy * 100))%")
                            .foregroundColor(flashcard.srsData.accuracy >= 0.8 ? AppTheme.success : AppTheme.amber)
                    }
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.stone)
                }
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
    @State private var description = ""
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        NavigationStack {
            Form {
                Section("Deck Name") {
                    TextField("Enter deck name", text: $name)
                }
                
                Section("Description (Optional)") {
                    TextField("Enter description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
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
                        store.addDeck(name: name, description: description)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents(isIPad ? [.large] : [.medium])
    }
}

struct EditDeckView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let deck: FlashcardDeck
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var dailyNewLimit: Int = 20
    @State private var dailyReviewLimit: Int = 100
    @State private var showingResetConfirmation = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        NavigationStack {
            Form {
                Section("Deck Info") {
                    TextField("Deck name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Daily Limits") {
                    Stepper("New cards: \(dailyNewLimit)", value: $dailyNewLimit, in: 1...100)
                    Stepper("Reviews: \(dailyReviewLimit)", value: $dailyReviewLimit, in: 10...500, step: 10)
                }
                
                Section("Statistics") {
                    LabeledContent("Total Cards", value: "\(deck.cards.count)")
                    LabeledContent("New Cards", value: "\(deck.newCount)")
                    LabeledContent("Due Cards", value: "\(deck.dueCount)")
                    if deck.totalAccuracy > 0 {
                        LabeledContent("Accuracy", value: "\(Int(deck.totalAccuracy * 100))%")
                    }
                }
                
                Section {
                    Button("Reset Progress", role: .destructive) {
                        showingResetConfirmation = true
                    }
                    
                    Button("Delete Deck", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .frame(maxWidth: isIPad ? 600 : .infinity)
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateDeck(
                            deckId: deck.id,
                            name: name,
                            description: description,
                            dailyNewLimit: dailyNewLimit,
                            dailyReviewLimit: dailyReviewLimit
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = deck.name
                description = deck.description
                dailyNewLimit = deck.dailyNewCardLimit
                dailyReviewLimit = deck.dailyReviewLimit
            }
            .alert("Reset Progress?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    store.resetDeckProgress(deckId: deck.id)
                    dismiss()
                }
            } message: {
                Text("This will reset all spaced repetition progress for this deck. Cards will be treated as new.")
            }
            .alert("Delete Deck?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deleteDeck(deckId: deck.id)
                    dismiss()
                }
            } message: {
                Text("This will permanently delete '\(deck.name)' and all its cards.")
            }
        }
        .presentationDetents(isIPad ? [.large] : [.large])
    }
}

struct EditFlashcardView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let deckId: UUID
    let card: Flashcard
    
    @State private var term: String = ""
    @State private var definition: String = ""
    @State private var notes: String = ""
    @State private var showingResetConfirmation = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        NavigationStack {
            Form {
                Section("Card Content") {
                    TextField("Character", text: $term)
                        .font(.system(size: 32))
                    TextField("Definition", text: $definition, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Progress") {
                    LabeledContent("Status", value: card.isNew ? "New" : (card.isDue ? "Due" : "Learned"))
                    LabeledContent("Total Reviews", value: "\(card.srsData.totalReviews)")
                    if card.srsData.totalReviews > 0 {
                        LabeledContent("Accuracy", value: "\(Int(card.srsData.accuracy * 100))%")
                        LabeledContent("Current Interval", value: "\(card.srsData.interval) days")
                        LabeledContent("Ease Factor", value: String(format: "%.2f", card.srsData.easeFactor))
                    }
                    if let lastReview = card.srsData.lastReviewDate {
                        LabeledContent("Last Review", value: lastReview.formatted(date: .abbreviated, time: .omitted))
                    }
                    LabeledContent("Next Review", value: card.srsData.nextReviewDate.formatted(date: .abbreviated, time: .omitted))
                }
                
                Section {
                    Button("Reset Progress", role: .destructive) {
                        showingResetConfirmation = true
                    }
                    
                    Button("Delete Card", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .frame(maxWidth: isIPad ? 600 : .infinity)
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateCard(
                            deckId: deckId,
                            cardId: card.id,
                            term: term,
                            definition: definition,
                            notes: notes
                        )
                        dismiss()
                    }
                    .disabled(term.isEmpty || definition.isEmpty)
                }
            }
            .onAppear {
                term = card.term
                definition = card.definition
                notes = card.notes
            }
            .alert("Reset Progress?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    store.resetCardProgress(deckId: deckId, cardId: card.id)
                    dismiss()
                }
            } message: {
                Text("This will reset the spaced repetition progress for this card.")
            }
            .alert("Delete Card?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deleteCard(deckId: deckId, cardId: card.id)
                    dismiss()
                }
            } message: {
                Text("This will permanently delete this card.")
            }
        }
        .presentationDetents(isIPad ? [.large] : [.large])
    }
}

#Preview {
    NavigationStack {
        MakeFlashcardsView()
            .environmentObject(FlashcardStore())
    }
}
