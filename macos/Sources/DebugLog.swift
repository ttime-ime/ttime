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

/// Where the time of one key goes, in milliseconds, written to the debug log as one line:
/// `queue` is how long the key waited before T-Time got it (system and the application's
/// side), `compose` the key policy, `insert` and `mark` the calls into the application,
/// `caret` asking it where the cursor is, `panel` redrawing the suggestion list.
final class KeyTiming {
    var queue = 0.0, compose = 0.0, insert = 0.0, mark = 0.0, caret = 0.0, panel = 0.0
    private let start = DispatchTime.now().uptimeNanoseconds

    @discardableResult
    func measure<T>(_ stage: ReferenceWritableKeyPath<KeyTiming, Double>, _ body: () -> T) -> T {
        let t = DispatchTime.now().uptimeNanoseconds
        defer { self[keyPath: stage] += Double(DispatchTime.now().uptimeNanoseconds - t) / 1e6 }
        return body()
    }

    func report(keyCode: UInt16, marked: Int, state: String) {
        let total = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        func f(_ v: Double) -> String { String(format: "%.2f", v) }
        DebugLog.log("timing keyCode=\(keyCode) queue=\(f(queue)) compose=\(f(compose)) insert=\(f(insert)) mark=\(f(mark)) caret=\(f(caret)) panel=\(f(panel)) ours=\(f(total))ms markedLen=\(marked) \(state)")
    }
}
