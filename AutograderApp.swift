import SwiftUI

@main
struct AutograderApp: App {
    @StateObject private var flashcardStore = FlashcardStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(flashcardStore)
        }
    }
}
