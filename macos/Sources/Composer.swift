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

    /// The characters of a `.text` key.
    var textValue: String { if case .text(let s) = self { return s } else { return "" } }
    var isUp: Bool { if case .up = self { return true } else { return false } }
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

    /// Sanskrit suggestions for Latin mode; nil when off or the word list is not loaded.
    /// Set it only between words (when focus arrives, after `reset`).
    var suggester: SanskritSuggester?

    /// What to show in the suggestion list, or nil when there is no list.
    var suggestionList: (words: [String], selected: Int)? {
        guard isLatin, let s = suggester, !s.shown.isEmpty else { return nil }
        return (s.shown, s.selected)
    }

    /// The word being typed in Latin mode, shown as marked text.
    var suggestionBuffer: String { suggester?.buffer ?? "" }

    // MARK: Long-press accents (Latin mode)

    /// Whether holding a letter offers its accented variants. Set it between words.
    var accents = false
    private var palette = AccentPalette()
    /// The letter the palette was opened for, and, once it closes, whose repeats are
    /// ignored until a fresh key press (the key may still be held, for example while
    /// a variant is clicked, and must not type itself again).
    private var paletteLetter = ""
    private var ignoreRepeats: String?
    private func closePalette() {
        if palette.isOpen { ignoreRepeats = paletteLetter }
        palette.close()
    }
    /// With no suggester, a letter that has variants waits as marked text until the next
    /// key, so a long press can still replace it. Empty otherwise.
    private var pending = ""

    /// What to show in the accent palette, or nil when it is closed.
    var accentList: (options: [String], selected: Int?)? {
        palette.isOpen ? (palette.options, palette.selected) : nil
    }

    /// The marked text now: the word being suggested for, or the waiting letter.
    private var shownText: String { suggester?.buffer ?? pending }
    /// The letter a long press would replace.
    private var heldLetter: String {
        if let s = suggester { return s.buffer.last.map(String.init) ?? "" }
        return pending
    }

    /// Accepts the suggestion at `index` (a click); nothing happens if there is no list.
    func chooseSuggestion(index: Int) -> Outcome {
        guard isLatin, suggester != nil, suggester!.select(index), let word = suggester!.accept() else { return Outcome() }
        return Outcome(insert: word, marked: "", handled: true)
    }

    /// Picks the highlighted variant (the held key was let go); nothing if none is highlighted.
    func chooseHighlightedAccent() -> Outcome {
        guard palette.isOpen, let i = palette.selected else { return Outcome() }
        return chooseAccent(palette.options[i])
    }

    /// Picks the palette entry at `index` (a click); nothing happens if it is closed.
    func chooseAccent(index: Int) -> Outcome {
        guard palette.isOpen, palette.options.indices.contains(index) else { return Outcome() }
        return chooseAccent(palette.options[index])
    }

    private func chooseAccent(_ variant: String) -> Outcome {
        closePalette()
        if suggester != nil {
            suggester!.replaceLast(with: variant)
            return Outcome(marked: suggester!.buffer, handled: true)
        }
        pending = ""
        return Outcome(insert: variant, marked: "", handled: true)
    }

    private func handleAccent(_ key: KeyInput, isRepeat: Bool) -> Outcome? {
        guard accents, isLatin else { return nil }
        if !isRepeat { ignoreRepeats = nil }
        if isRepeat, let ignored = ignoreRepeats, case .text(let s) = key, s == ignored {
            return Outcome(marked: shownText, handled: true)
        }
        if palette.isOpen {
            switch key {
            case .text(let s):
                if isRepeat { return Outcome(marked: shownText, handled: true) }
                if let n = Int(s), let v = palette.option(number: n) { return chooseAccent(v) }
                if s == " ", let i = palette.selected { return chooseAccent(palette.options[i]) }
            case .left, .up:
                palette.move(-1)
                return Outcome(marked: shownText, handled: true)
            case .right, .down:
                palette.move(1)
                return Outcome(marked: shownText, handled: true)
            case .tab:
                palette.cycle()
                return Outcome(marked: shownText, handled: true)
            case .enter:
                if let i = palette.selected { return chooseAccent(palette.options[i]) }
            case .escape:
                closePalette()
                return Outcome(marked: shownText, handled: true)
            default: break
            }
            // Any other key keeps the plain letter and then does what it normally does.
            closePalette()
        }
        if case .text(let s) = key {
            // The key repeating means it is held: offer the variants of the letter just typed.
            if isRepeat, AccentPalette.hasVariants(s), heldLetter == s {
                palette.open(for: s)
                paletteLetter = s
                return Outcome(marked: shownText, handled: true)
            }
            guard suggester == nil else { return nil }
            let before = pending
            pending = ""
            if AccentPalette.hasVariants(s) {
                pending = s
                return Outcome(insert: before, marked: s, handled: true)
            }
            guard !before.isEmpty else { return nil }
            ttime_session_insert(session, s)
            return Outcome(insert: before + take(ttime_session_take_committed(session)), marked: "", handled: true)
        }
        guard suggester == nil, !pending.isEmpty else { return nil }
        let before = pending
        pending = ""
        switch key {
        case .backspace: return Outcome(marked: "", handled: true)
        case .escape: return Outcome(insert: before, marked: "", handled: true)
        default: return Outcome(insert: before, marked: "", handled: false)
        }
    }

    private func handleSuggesting(_ key: KeyInput) -> Outcome? {
        guard isLatin, suggester != nil else { return nil }
        let marked: () -> String = { self.suggester?.buffer ?? "" }
        switch key {
        case .text(let s) where SanskritSuggester.isLetter(s):
            suggester!.type(s)
            return Outcome(marked: marked(), handled: true)
        case .text:
            // A space, digit or punctuation ends the word: it goes in as typed.
            let word = suggester!.flush()
            ttime_session_insert(session, key.textValue)
            return Outcome(insert: word + take(ttime_session_take_committed(session)), marked: "", handled: true)
        case .backspace:
            guard suggester!.backspace() else { return nil }
            return Outcome(marked: marked(), handled: true)
        case .escape:
            guard !suggester!.isEmpty else { return nil }
            return Outcome(insert: suggester!.flush(), marked: "", handled: true)
        case .tab:
            guard !suggester!.isEmpty else { return nil }
            if let word = suggester!.accept() { return Outcome(insert: word, marked: "", handled: true) }
            return Outcome(insert: suggester!.flush(), marked: "", handled: false)
        case .up, .down:
            guard !suggester!.shown.isEmpty else { break }
            suggester!.move(key.isUp ? -1 : 1)
            return Outcome(marked: marked(), handled: true)
        default: break
        }
        // Return, arrows with no list, shortcuts: the typed word is committed, then the
        // application receives the key.
        guard !suggester!.isEmpty else { return nil }
        return Outcome(insert: suggester!.flush(), marked: "", handled: false)
    }

    /// `isRepeat` is true for the repeats of a held key (a long press).
    func handle(_ key: KeyInput, isRepeat: Bool = false) -> Outcome {
        if let out = handleAccent(key, isRepeat: isRepeat) { return out }
        if let out = handleSuggesting(key) { return out }
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
        let word = flushSuggestion()
        ttime_session_set_latin(session, on)
        return Outcome(insert: word + take(ttime_session_take_committed(session)), marked: "", handled: true)
    }

    /// Commits any pending text and returns everything not yet inserted.
    func commitAll() -> String {
        flushSuggestion() + take(ttime_session_finish(session))
    }

    /// Forgets pending input, for example when the input source is activated.
    func reset() {
        suggester?.clear()
        pending = ""
        palette.close()
        ttime_session_cancel(session); _ = take(ttime_session_take_committed(session))
    }

    /// The word or letter waiting as marked text, as plain text; clears it and the palette.
    private func flushSuggestion() -> String {
        palette.close()
        let waiting = pending
        pending = ""
        return (suggester?.flush() ?? "") + waiting
    }
}
