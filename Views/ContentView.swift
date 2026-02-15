import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isIPad = horizontalSizeClass == .regular
                let buttonWidth = isIPad ? min(400, geometry.size.width * 0.4) : geometry.size.width - 64
                let buttonHeight: CGFloat = isIPad ? 200 : 140
                let spacing: CGFloat = isIPad ? 40 : 24
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    if isIPad {
                        // iPad: side-by-side buttons
                        HStack(spacing: spacing) {
                            NavigationLink(destination: FlashcardModeView()) {
                                MainMenuButton(
                                    title: "Flashcard Mode",
                                    subtitle: "Study your cards",
                                    systemImage: "rectangle.stack.fill",
                                    color: .blue
                                )
                            }
                            .frame(width: buttonWidth, height: buttonHeight)
                            
                            NavigationLink(destination: MakeFlashcardsView()) {
                                MainMenuButton(
                                    title: "Make Flashcards",
                                    subtitle: "Create new cards",
                                    systemImage: "plus.rectangle.fill",
                                    color: .green
                                )
                            }
                            .frame(width: buttonWidth, height: buttonHeight)
                        }
                    } else {
                        // iPhone: stacked buttons
                        VStack(spacing: spacing) {
                            NavigationLink(destination: FlashcardModeView()) {
                                MainMenuButton(
                                    title: "Flashcard Mode",
                                    subtitle: "Study your cards",
                                    systemImage: "rectangle.stack.fill",
                                    color: .blue
                                )
                            }
                            .frame(width: buttonWidth, height: buttonHeight)
                            
                            NavigationLink(destination: MakeFlashcardsView()) {
                                MainMenuButton(
                                    title: "Make Flashcards",
                                    subtitle: "Create new cards",
                                    systemImage: "plus.rectangle.fill",
                                    color: .green
                                )
                            }
                            .frame(width: buttonWidth, height: buttonHeight)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Flashcards")
        }
    }
}

struct MainMenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.white)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color.gradient)
        )
        .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ContentView()
        .environmentObject(FlashcardStore())
}
