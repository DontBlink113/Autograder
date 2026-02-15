import SwiftUI

struct ProgressPanelView: View {
    @EnvironmentObject var store: FlashcardStore
    @ObservedObject var betaStore = CharacterBetaStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var activeCharacterStats: [CharacterBetaStats] {
        betaStore.getActiveCharacterStats(activeCharacters: store.allActiveCharacters)
    }
    
    var body: some View {
        let isIPad = horizontalSizeClass == .regular
        
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Characters")
                                    .font(AppTheme.Typography.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("\(activeCharacterStats.count) characters being tracked")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(AppTheme.forestGreen.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                Text("\(activeCharacterStats.count)")
                                    .font(AppTheme.Typography.title)
                                    .foregroundColor(AppTheme.forestGreen)
                            }
                        }
                        
                        if !activeCharacterStats.isEmpty {
                            // Average mastery
                            let avgMastery = activeCharacterStats.reduce(0.0) { $0 + $1.expectedValue } / Double(activeCharacterStats.count)
                            
                            HStack {
                                Text("Average Mastery")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("\(Int(avgMastery * 100))%")
                                    .font(AppTheme.Typography.headline)
                                    .foregroundColor(masteryColor(avgMastery))
                            }
                            
                            ProgressView(value: avgMastery)
                                .tint(masteryColor(avgMastery))
                        }
                    }
                    .padding(20)
                    .background(AppTheme.backgroundCard)
                    .cornerRadius(AppTheme.Radius.lg)
                    .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                    
                    // Character List
                    if activeCharacterStats.isEmpty {
                        ContentUnavailableView(
                            "No Active Characters",
                            systemImage: "character.book.closed",
                            description: Text("Activate decks or add characters to start tracking progress")
                        )
                        .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Character Mastery")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal)
                            
                            Text("Sorted by weakest first (Beta distribution expected value)")
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: isIPad ? 120 : 100), spacing: 12)
                            ], spacing: 12) {
                                ForEach(activeCharacterStats) { stats in
                                    CharacterMasteryCard(stats: stats)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func masteryColor(_ value: Double) -> Color {
        if value >= 0.8 {
            return AppTheme.success
        } else if value >= 0.5 {
            return AppTheme.amber
        } else {
            return AppTheme.error
        }
    }
}

struct CharacterMasteryCard: View {
    let stats: CharacterBetaStats
    
    var body: some View {
        VStack(spacing: 8) {
            Text(stats.character)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(AppTheme.gold)
            
            // Expected value as percentage
            Text("\(Int(stats.expectedValue * 100))%")
                .font(AppTheme.Typography.headline)
                .foregroundColor(masteryColor(stats.expectedValue))
            
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.stone.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(masteryColor(stats.expectedValue))
                        .frame(width: geo.size.width * stats.expectedValue, height: 4)
                }
            }
            .frame(height: 4)
            
            // Stats
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.success)
                Text("\(stats.successes)")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.error)
                Text("\(stats.failures)")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(12)
        .background(AppTheme.backgroundCard)
        .cornerRadius(AppTheme.Radius.md)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
    
    private func masteryColor(_ value: Double) -> Color {
        if value >= 0.8 {
            return AppTheme.success
        } else if value >= 0.5 {
            return AppTheme.amber
        } else {
            return AppTheme.error
        }
    }
}

#Preview {
    NavigationStack {
        ProgressPanelView()
            .environmentObject(FlashcardStore())
    }
}
