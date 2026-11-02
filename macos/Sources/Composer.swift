import Foundation

/// A keystroke reduced to what the engine cares about.
enum KeyInput {
    /// Printable characters; all of ASCII is EWTS input.
    case text(String)
    case backspace
    case escape
    case enter
    /// Anything else (arrows, tab, shortcuts): commit what is pending, then let
    /// the application handle the key.
    case other
}

/// What the input controller should do with the client application.
struct Outcome: Equatable {
    /// Text to insert into the document (committed Tibetan), possibly empty.
    var insert = ""
    /// The whole provisional run to show as marked text; empty clears it.
    var marked = ""
    /// Whether T-Time consumed the key. If false the application gets it.
    var handled = false
}

/// Key policy on top of the C engine. No UI dependencies, so it is testable.
final class Composer {
    private var session: OpaquePointer?

    init(precomposed: Bool = false) {
        session = ttime_session_new(precomposed)
    }

    deinit { ttime_session_free(session) }

    private func take(_ p: UnsafeMutablePointer<CChar>?) -> String {
        guard let p = p else { return "" }
        defer { ttime_string_free(p) }
        return String(cString: p)
    }

    private var provisional: String { take(ttime_session_provisional(session)) }
    private var composing: Bool { ttime_session_has_provisional(session) }

    func handle(_ key: KeyInput) -> Outcome {
        switch key {
        case .text(let s):
            ttime_session_insert(session, s)
            return Outcome(insert: take(ttime_session_take_committed(session)),
                           marked: provisional, handled: true)
        case .backspace:
            guard ttime_session_backspace(session) else { return Outcome() }
            return Outcome(marked: provisional, handled: true)
        case .escape:
            guard composing else { return Outcome() }
            ttime_session_cancel(session)
            return Outcome(handled: true)
        case .enter:
            guard composing else { return Outcome() }
            return Outcome(insert: take(ttime_session_finish(session)), handled: true)
        case .other:
            return Outcome(insert: commitAll(), handled: false)
        }
    }

    /// Commits any pending text and returns everything not yet inserted.
    func commitAll() -> String {
        take(ttime_session_finish(session))
    }

    /// Forgets pending input, for example when the input source is activated.
    func reset() { ttime_session_cancel(session); _ = take(ttime_session_take_committed(session)) }
}
