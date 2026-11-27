import SwiftUI

@main
struct TapezeApp: App {
    @State private var isShowingMicReady = false
    /// Changes on every mic-key launch so an open card starts the mic again.
    @State private var micLaunch = UUID()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    guard DictationBridge.isDictateURL(url) else { return }
                    micLaunch = UUID()
                    isShowingMicReady = true
                }
                .fullScreenCover(isPresented: $isShowingMicReady) {
                    MicReadyView(launch: micLaunch) { isShowingMicReady = false }
                }
        }
    }
}
