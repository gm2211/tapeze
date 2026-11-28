import SwiftUI

@main
struct TapezeApp: App {
    @State private var isShowingMicReady = false
    /// Changes on every mic-key launch so an open card starts the mic again.
    @State private var micLaunch = UUID()
    @State private var isEditingToolColumn = false

    var body: some Scene {
        WindowGroup {
            ContentView(isEditingToolColumn: $isEditingToolColumn)
                .onOpenURL { url in
                    if url == ToolColumnConfig.settingsURL {
                        isEditingToolColumn = true
                        return
                    }
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
