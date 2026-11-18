import Foundation

/// A keystroke reduced to what the engine cares about.
enum KeyInput {
    /// Printable characters; all of ASCII is EWTS input.
    case text(String)
    case backspace
    case escape
    case enter
    /// Navigation keys, used by the stacker and symbols windows when open.
    case tab, up, down, left, right
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

    private(set) var precomposed: Bool

    init(precomposed: Bool = false) {
        self.precomposed = precomposed
        session = ttime_session_new(precomposed)
    }

    /// Switches the output form. Anything being typed is dropped, so call it only
    /// between compositions (when focus arrives).
    func setPrecomposed(_ on: Bool) {
        guard on != precomposed else { return }
        let latin = isLatin
        ttime_session_free(session)
        precomposed = on
        session = ttime_session_new(on)
        if latin { ttime_session_set_latin(session, true) }
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
        case .enter, .other, .tab, .up, .down, .left, .right:
            // Commit what is pending, then let the application take the key
            // (Return starts a new line).
            return Outcome(insert: commitAll(), handled: false)
        }
    }

    var isLatin: Bool { ttime_session_is_latin(session) }

    /// Switches between Tibetan and Latin. Pending Tibetan is fixed first and
    /// comes back as `insert`; the marked text is cleared.
    func setLatin(_ on: Bool) -> Outcome {
        ttime_session_set_latin(session, on)
        return Outcome(insert: take(ttime_session_take_committed(session)), marked: "", handled: true)
    }

    /// Commits any pending text and returns everything not yet inserted.
    func commitAll() -> String {
        take(ttime_session_finish(session))
    }

    /// Forgets pending input, for example when the input source is activated.
    func reset() { ttime_session_cancel(session); _ = take(ttime_session_take_committed(session)) }
}
