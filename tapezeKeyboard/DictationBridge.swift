import Foundation

/// Hands dictated text from the Tapeze app to the keyboard.
///
/// iOS doesn't let a keyboard extension record the microphone or start the
/// system's dictation, so the mic key opens the app instead. The app listens,
/// leaves the text here when the user goes back, and the keyboard types it
/// into the field it came from.
enum DictationBridge {
    static let urlScheme = "tapeze"
    static let dictateHost = "dictate"
    static let dictateURL = URL(string: "\(urlScheme)://\(dictateHost)")!

    /// Text older than this is dropped rather than typed, so a dictation the
    /// user abandoned never shows up later in an unrelated field.
    static let maxPendingAge: TimeInterval = 10 * 60

    private static let pendingTextKey = "dictation.pendingText"
    private static let deliveredAtKey = "dictation.deliveredAt"

    private static var defaults: UserDefaults { KeyboardState.settingsDefaults }

    static func isDictateURL(_ url: URL) -> Bool {
        url.scheme == urlScheme && url.host == dictateHost
    }

    /// Called by the app when the user finishes speaking.
    static func deliver(_ text: String, now: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: pendingTextKey)
        defaults.set(now.timeIntervalSince1970, forKey: deliveredAtKey)
    }

    /// Called by the keyboard when it comes back on screen. Returns the text
    /// at most once.
    static func takePendingText(now: Date = Date()) -> String? {
        guard let text = defaults.string(forKey: pendingTextKey) else { return nil }
        let deliveredAt = defaults.double(forKey: deliveredAtKey)
        clear()
        guard now.timeIntervalSince1970 - deliveredAt < maxPendingAge else { return nil }
        return text
    }

    static func clear() {
        defaults.removeObject(forKey: pendingTextKey)
        defaults.removeObject(forKey: deliveredAtKey)
    }

    /// The text to insert after `before`, with a space added when the
    /// dictation would otherwise run into the previous word.
    static func textToInsert(_ text: String, after before: String?) -> String {
        guard let last = before?.last, !last.isWhitespace else { return text }
        if let first = text.first, first.isPunctuation { return text }
        return " " + text
    }
}
