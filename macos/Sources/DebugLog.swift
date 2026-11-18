import Foundation

/// An opt-in diagnostic log for modifier-key problems, off by default. Turn it on with
///   defaults write io.github.ttime-ime.inputmethod.TTime DebugKeys -bool true
/// and off with `defaults delete ...`. It writes to ~/Library/Logs/T-Time-keys.log.
/// It records modifier changes, key codes and what T-Time decided, never the characters typed.
enum DebugLog {
    static var enabled: Bool { Prefs.debugKeys }

    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/T-Time-keys.log")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = "\(stamp.string(from: Date())) \(message())\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            try? h.close()
        } else {
            try? line.write(to: url, atomically: false, encoding: .utf8)
        }
    }
}
