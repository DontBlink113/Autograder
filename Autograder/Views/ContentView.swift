import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: FlashcardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                AppTheme.backgroundPrimary
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    let isIPad = horizontalSizeClass == .regular
                    let gridWidth = isIPad ? min(600, geometry.size.width - 80) : geometry.size.width - 32
                    let modeButtonSize: CGFloat = isIPad ? 140 : (gridWidth - 16) / 2
                    let spacing: CGFloat = isIPad ? 20 : 12
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Hero Section
                            VStack(spacing: 6) {
                                Text("汉字")
                                    .font(.system(size: isIPad ? 64 : 48, weight: .bold))
                                    .foregroundColor(AppTheme.gold)
                                
                                Text("Excellence One Step at a Time")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.top, isIPad ? 32 : 16)
                            
                            // Stats Bar
                            HStack(spacing: 0) {
                                QuickStatView(
                                    value: "\(store.totalCardsAcrossDecks)",
                                    label: "Active",
                                    icon: "character.book.closed.fill",
                                    color: AppTheme.forestGreen
                                )
                                
                                Divider()
                                    .frame(height: 32)
                                
                                QuickStatView(
                                    value: "\(store.streakDays)",
                                    label: "Streak",
                                    icon: "flame.fill",
                                    color: store.streakDays > 0 ? AppTheme.amber : AppTheme.stone
                                )
                                
                                Divider()
                                    .frame(height: 32)
                                
                                QuickStatView(
                                    value: "\(Int(store.overallAccuracy * 100))%",
                                    label: "Accuracy",
                                    icon: "target",
                                    color: AppTheme.success
                                )
                            }
                            .padding(.vertical, 12)
                            .background(AppTheme.backgroundCard)
                            .cornerRadius(AppTheme.Radius.md)
                            .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 3)
                            .padding(.horizontal, 16)
                            
                            // EXCEL MODE - Central Gold Button
                            // Mode Grid - 2x2
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: spacing),
                                GridItem(.flexible(), spacing: spacing)
                            ], spacing: spacing) {
                                // Excel Mode - Top Left (Gold)
                                NavigationLink(destination: ExcelModeView()) {
                                    ExcelModeButton(isIPad: isIPad)
                                }
                                .frame(height: modeButtonSize)
                                
                                // Grammar - Top Right
                                NavigationLink(destination: GrammarModeView()) {
                                    ModeButton(
                                        title: "Grammar",
                                        icon: "text.book.closed.fill",
                                        color: AppTheme.forestGreenLight
                                    )
                                }
                                .frame(height: modeButtonSize)
                                
                                // Calligraphy (was Flashcards) - Bottom Left
                                NavigationLink(destination: CalligraphyModeView()) {
                                    ModeButton(
                                        title: "Calligraphy",
                                        icon: "paintbrush.pointed.fill",
                                        color: AppTheme.forestGreen
                                    )
                                }
                                .frame(height: modeButtonSize)
                                
                                // Flashcards - Bottom Right
                                NavigationLink(destination: FlashcardsView()) {
                                    ModeButton(
                                        title: "Flashcards",
                                        icon: "rectangle.stack.fill",
                                        color: AppTheme.forestGreen
                                    )
                                }
                                .frame(height: modeButtonSize)
                            }
                            .padding(.horizontal, 16)
                            
                            Spacer(minLength: 24)
                            
                            // Tortoise at bottom - flipped horizontally
                            Image("Tortoise")
                                .resizable()
                                .scaledToFit()
                                .frame(width: isIPad ? 180 : 120, height: isIPad ? 180 : 120)
                                .scaleEffect(x: -1, y: 1)  // Flip horizontally
                                .opacity(0.9)
                            
                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Walking Chinese")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.forestGreen)
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: ProgressPanelView()) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppTheme.forestGreen)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: MakeFlashcardsView()) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .tint(AppTheme.forestGreen)
    }
}

// MARK: - Excel Mode Button (Gold, Grid-sized)
struct ExcelModeButton: View {
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.4), Color(red: 0.85, green: 0.65, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: AppTheme.amber.opacity(0.4), radius: 6, x: 0, y: 3)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Excel")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.75, blue: 0.3), Color(red: 0.85, green: 0.65, blue: 0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .fill(AppTheme.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.85, blue: 0.4), Color(red: 0.85, green: 0.65, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: AppTheme.amber.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Mode Button
struct ModeButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(AppTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .fill(AppTheme.backgroundCard)
        )
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 3)
    }
}

// MARK: - Grammar Mode (redirects to GrammarPracticeView)
struct GrammarModeView: View {
    var body: some View {
        GrammarPracticeView()
    }
}

// Calligraphy Mode - Drawing practice (uses FlashcardModeView)
struct CalligraphyModeView: View {
    var body: some View {
        FlashcardModeView()
    }
}

// Standard Flashcards View - Flip cards to study (simplified: just flip and navigate)
struct FlashcardsView: View {
    @EnvironmentObject var store: FlashcardStore
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var studyQueue: [Flashcard] = []
    
    var currentCard: Flashcard? {
        guard !studyQueue.isEmpty, currentIndex < studyQueue.count else { return nil }
        return studyQueue[currentIndex]
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let _ = store.selectedDeck, !studyQueue.isEmpty, let card = currentCard {
                    // Progress
                    HStack {
                        Text("\(currentIndex + 1) / \(studyQueue.count)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Flashcard
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                            .fill(AppTheme.backgroundCard)
                            .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 16) {
                            if isFlipped {
                                // Back - Definition
                                Text(card.definition)
                                    .font(AppTheme.Typography.title)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                
                                Text(card.term)
                                    .font(.system(size: 80, weight: .medium))
                                    .foregroundColor(AppTheme.forestGreen)
                            } else {
                                // Front - Character
                                Text(card.term)
                                    .font(.system(size: 120, weight: .medium))
                                    .foregroundColor(AppTheme.gold)
                                
                                Text("Tap to flip")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: 350, maxHeight: 400)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isFlipped.toggle()
                        }
                    }
                    
                    Spacer()
                    
                    // Navigation buttons (prev / flip / next)
                    HStack(spacing: 40) {
                        Button(action: prevCard) {
                            VStack {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 44))
                                Text("Prev")
                                    .font(AppTheme.Typography.caption)
                            }
                            .foregroundColor(currentIndex > 0 ? AppTheme.forestGreen : AppTheme.stone)
                        }
                        .disabled(currentIndex == 0)
                        
                        Button(action: { withAnimation(.spring()) { isFlipped.toggle() } }) {
                            VStack {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 44))
                                Text("Flip")
                                    .font(AppTheme.Typography.caption)
                            }
                            .foregroundColor(AppTheme.gold)
                        }
                        
                        Button(action: nextCard) {
                            VStack {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 44))
                                Text("Next")
                                    .font(AppTheme.Typography.caption)
                            }
                            .foregroundColor(currentIndex < studyQueue.count - 1 ? AppTheme.forestGreen : AppTheme.stone)
                        }
                        .disabled(currentIndex >= studyQueue.count - 1)
                    }
                    .padding(.bottom, 20)
                    
                } else {
                    ContentUnavailableView(
                        "No Cards to Study",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Select a deck or add flashcards to start")
                    )
                }
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(store.decks) { deck in
                        Button(action: {
                            store.selectedDeckId = deck.id
                            loadStudyQueue()
                        }) {
                            HStack {
                                Text(deck.name)
                                if deck.id == store.selectedDeckId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(store.selectedDeck?.name ?? "Select Deck")
                            .font(AppTheme.Typography.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(AppTheme.forestGreen)
                }
            }
        }
        .onAppear {
            loadStudyQueue()
        }
    }
    
    private func loadStudyQueue() {
        if let deckId = store.selectedDeckId {
            studyQueue = store.getStudyQueue(forDeckId: deckId)
            currentIndex = 0
            isFlipped = false
        }
    }
    
    private func prevCard() {
        if currentIndex > 0 {
            currentIndex -= 1
            isFlipped = false
        }
    }
    
    private func nextCard() {
        if currentIndex < studyQueue.count - 1 {
            currentIndex += 1
            isFlipped = false
        }
    }
}

enum MenuButtonStyle {
    case primary
    case accent
    case secondary
}

struct MainMenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let style: MenuButtonStyle
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return AppTheme.forestGreen
        case .accent: return AppTheme.amber
        case .secondary: return AppTheme.backgroundCard
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .accent: return AppTheme.charcoal
        case .secondary: return AppTheme.forestGreen
        }
    }
    
    private var subtitleColor: Color {
        switch style {
        case .primary: return .white.opacity(0.85)
        case .accent: return AppTheme.charcoal.opacity(0.7)
        case .secondary: return AppTheme.stone
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(foregroundColor.opacity(style == .primary ? 0.2 : 0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.Typography.title2)
                    .foregroundColor(foregroundColor)
                
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(subtitleColor)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(foregroundColor.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(backgroundColor)
        )
        .shadow(color: backgroundColor.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

struct QuickStatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(AppTheme.Typography.title2)
                    .foregroundColor(color)
            }
            Text(label)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(FlashcardStore())
}
