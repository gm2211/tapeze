import SwiftUI

@main
struct TapezeApp: App {
    @State private var isDictating = false
    /// Changes on every mic-key launch so an already-open dictation screen
    /// starts listening again.
    @State private var dictationSession = UUID()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    guard DictationBridge.isDictateURL(url) else { return }
                    dictationSession = UUID()
                    isDictating = true
                }
                .fullScreenCover(isPresented: $isDictating) {
                    DictationView(sessionID: dictationSession) { isDictating = false }
                }
        }
    }
}
