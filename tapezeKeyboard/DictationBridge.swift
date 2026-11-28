import Foundation

/// What the Tapeze app's microphone is doing, shared with the keyboard through
/// the app group.
struct DictationStatus: Codable, Equatable {
    enum Phase: String, Codable {
        /// The mic is warm (or off) and nothing is being transcribed.
        case idle
        /// Transcribing `session` right now.
        case listening
        /// `session` ended; `transcript` is its final text.
        case finished
        /// `session` was thrown away.
        case cancelled
        /// The app can't listen (permissions, recognizer); see `message`.
        case unavailable
    }

    var session: Int = 0
    var phase: Phase = .idle
    var transcript: String = ""
    /// Input loudness, 0...1, for the keyboard's waveform.
    var level: Float = 0
    /// When the app last confirmed its mic is running. Zero when it's off.
    var heartbeat: TimeInterval = 0
    var message: String?
}

/// Lets the keyboard dictate without leaving the host app.
///
/// iOS doesn't let a keyboard extension record audio, and an app can only
/// switch the microphone on while it's on screen. So the first mic tap opens
/// Tapeze, which starts the mic and keeps it running in the background for a
/// few minutes. While it's warm, the keyboard starts and stops dictation with
/// Darwin notifications, and the app streams the transcript back through a
/// file in the app group.
enum DictationBridge {
    static let urlScheme = "tapeze"
    static let dictateHost = "dictate"
    static let dictateURL = URL(string: "\(urlScheme)://\(dictateHost)")!

    /// How long the app keeps the mic warm after the last dictation.
    static let warmIdleTimeout: TimeInterval = 5 * 60
    /// The app refreshes its heartbeat at least this often while warm.
    static let heartbeatInterval: TimeInterval = 0.5
    /// A heartbeat older than this means the app's mic is no longer running.
    static let heartbeatTimeout: TimeInterval = 2.5

    // Keyboard → app.
    static let startNotification = "com.gm2211.tapeze.dictation.start"
    static let stopNotification = "com.gm2211.tapeze.dictation.stop"
    static let cancelNotification = "com.gm2211.tapeze.dictation.cancel"
    // App → keyboard.
    static let updateNotification = "com.gm2211.tapeze.dictation.update"

    static func isDictateURL(_ url: URL) -> Bool {
        url.scheme == urlScheme && url.host == dictateHost
    }

    // MARK: Status file

    private static var statusURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: KeyboardState.appGroupSuiteName)?
            .appendingPathComponent("dictation-status.json")
    }

    static func readStatus() -> DictationStatus {
        guard let url = statusURL,
              let data = try? Data(contentsOf: url),
              let status = try? JSONDecoder().decode(DictationStatus.self, from: data)
        else { return DictationStatus() }
        return status
    }

    static func writeStatus(_ status: DictationStatus) {
        guard let url = statusURL,
              let data = try? JSONEncoder().encode(status) else { return }
        try? data.write(to: url, options: .atomic)
        post(updateNotification)
    }

    static func isWarm(_ status: DictationStatus, now: Date = Date()) -> Bool {
        status.phase != .unavailable
            && status.heartbeat > 0
            && now.timeIntervalSince1970 - status.heartbeat < heartbeatTimeout
    }

    // MARK: Darwin notifications

    private static var handlers: [String: () -> Void] = [:]

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    /// Calls `handler` on the main queue whenever `name` is posted by any
    /// process. One handler per name.
    static func observe(_ name: String, handler: @escaping () -> Void) {
        let isNew = handlers[name] == nil
        handlers[name] = handler
        guard isNew else { return }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, cfName, _, _ in
                guard let raw = cfName?.rawValue as String? else { return }
                DispatchQueue.main.async { DictationBridge.handlers[raw]?() }
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    // MARK: Text

    /// The leading text to put before dictation that follows `before`, so it
    /// doesn't run into the previous word.
    static func leadingSpace(after before: String?) -> String {
        guard let last = before?.last, !last.isWhitespace else { return "" }
        return " "
    }

    /// How to turn `old` into `new` in a text field with only backspace and
    /// insert: how many characters to delete, then what to type.
    static func edit(from old: String, to new: String) -> (delete: Int, insert: String) {
        let common = zip(old, new).prefix { $0 == $1 }.count
        return (old.count - common, String(new.dropFirst(common)))
    }
}
