import Cocoa
import InputMethodKit

/// Connects the system's text input events to a `Composer`. One controller is
/// created per client application.
@objc(TTimeInputController)
final class TTimeInputController: IMKInputController {
    private let composer = Composer(precomposed: Prefs.precomposed)
    private var shiftTap = ShiftTap()

    /// The Tibetan/Latin lock, shared by every client application so no
    /// controller can disagree about it. Persisted across restarts.
    private static let lockKey = "ModeLockLatin"  // "latin", "tibetan" or absent
    private static var lock: ModeLock = {
        switch UserDefaults.standard.string(forKey: lockKey) {
        case "latin": return ModeLock(lockedLatin: true)
        case "tibetan": return ModeLock(lockedLatin: false)
        default: return ModeLock()
        }
    }()
    private static func saveLock() {
        let v = lock.lockedLatin.map { $0 ? "latin" : "tibetan" }
        if let v = v { UserDefaults.standard.set(v, forKey: lockKey) }
        else { UserDefaults.standard.removeObject(forKey: lockKey) }
    }
    private let noRange = NSRange(location: NSNotFound, length: NSNotFound)

    /// The controller whose client currently has focus; the toolbar acts on it.
    private static weak var active: TTimeInputController?
    /// Last document we typed into (not T-Time's own windows). Stacker/Symbols
    /// clicks land in the IME process and can deactivate or rewire `client`;
    /// inserts still go here.
    private static weak var documentClient: IMKTextInput?
    private var client: IMKTextInput?

    private var toolbarState: Toolbar.State {
        Toolbar.State(latin: composer.isLatin, locked: Self.lock.lockedLatin != nil)
    }
    private func refreshToolbar() {
        if Self.active === self { Toolbar.shared.update(toolbarState) }
    }

    // Shift taps arrive as modifier changes, not key presses.
    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }
        // Remember the document while keys still arrive from it (panel clicks can
        // clear or replace `self.client` via activate/deactivate).
        if client.bundleIdentifier() != Bundle.main.bundleIdentifier {
            self.client = client
            Self.documentClient = client
        }
        // The dictionary page has the keyboard: its client is this very process, so
        // letting the system deliver text to it would make T-Time talk to itself
        // (slow, and it can stall typing everywhere). Take the keys and put them
        // into the page directly; the site does its own EWTS conversion.
        // Only when the client really is the panel (not Spotlight or another
        // application while the panel merely still counts as the key window).
        if DictionaryPanel.shared.hasKeyboard, client.bundleIdentifier() == Bundle.main.bundleIdentifier {
            if event.type == .keyDown, DictionaryPanel.shared.type(event) { return true }
            return false
        }
        if event.type == .flagsChanged {
            DebugLog.log("flagsChanged keyCode=\(event.keyCode) flags=0x\(String(event.modifierFlags.rawValue, radix: 16)) t=\(event.timestamp) latin=\(composer.isLatin)")
            if let tap = shiftTap.flagsChanged(keyCode: event.keyCode,
                                               flags: UInt(event.modifierFlags.rawValue),
                                               time: event.timestamp) {
                DebugLog.log("  tap \(tap.side) \(tap.kind) -> lock=\(String(describing: Self.lock.lockedLatin))")
                shiftTapped(tap, client: client)
            }
            // Never consume a modifier change: the application must see the
            // Shift release, or it believes Shift is stuck down.
            return false
        }
        guard event.type == .keyDown else { return false }
        DebugLog.log("keyDown keyCode=\(event.keyCode) repeat=\(event.isARepeat) t=\(event.timestamp) flags=0x\(String(event.modifierFlags.rawValue, radix: 16))")
        shiftTap.keyDown()
        // Option+Shift+` (the key left of 1) opens and closes the stacker.
        if event.keyCode == 50, event.modifierFlags.contains([.option, .shift]) {
            toggleStacker()
            return true
        }
        // Control+Shift+F (the F key) opens and closes the dictionary.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 3, mods == [.control, .shift] {
            toggleDictionary()
            return true
        }
        // Spotlight never shows text we insert. Hand the key back so the
        // letter the keyboard produced appears in the search field. Tibetan
        // conversion needs that insertion, so a search is typed in Latin.
        if ClientText.showsOnlyRawKeys(client.bundleIdentifier()) {
            DebugLog.log("spotlight: key passed through")
            return false
        }
        if StackerPanel.shared.isOpen {
            if StackerPanel.shared.handle(keyInput(for: event)) { return true }
        } else if SymbolsPanel.shared.isOpen {
            if SymbolsPanel.shared.handle(keyInput(for: event)) { return true }
        } else if DictionaryPanel.shared.isOpen {
            if DictionaryPanel.shared.handle(keyInput(for: event)) { return true }
        }
        // With the debug log on, record where the time of this key goes (no characters).
        // The word list loads in the background; a controller that was activated before it
        // was ready has no suggester, so pick it up as soon as it is.
        if composer.lexicon == nil, Prefs.sanskritSuggestions, let lexicon = SanskritLexicon.shared {
            composer.lexicon = lexicon
        }
        let timing: KeyTiming? = DebugLog.enabled ? KeyTiming() : nil
        timing?.queue = max(0, ProcessInfo.processInfo.systemUptime - event.timestamp)
        let outcome = timing.map { t in t.measure(\.compose) { composer.handle(keyInput(for: event), isRepeat: event.isARepeat) } }
            ?? composer.handle(keyInput(for: event), isRepeat: event.isARepeat)
        self.timing = timing
        apply(outcome, to: client)
        self.timing = nil
        timing?.report(keyCode: event.keyCode, marked: outcome.marked.utf16.count,
                       state: "latin=\(composer.isLatin) suggester=\(composer.lexicon != nil) list=\(composer.suggestionList?.words.count ?? 0)")
        if event.isARepeat, composer.accentList != nil, heldWatch == nil { watchHeldKey(CGKeyCode(event.keyCode)) }
        return outcome.handled
    }

    /// There is no key-release event for an input method, so while the accent strip is
    /// open the held key's state is polled. Letting go of it with a variant highlighted
    /// (Tab or the arrows) picks that variant, as the system's palette does.
    private var heldWatch: Timer?
    private func watchHeldKey(_ code: CGKeyCode) {
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard self.composer.accentList != nil else { self.stopWatching(); return }
            if !CGEventSource.keyState(.combinedSessionState, key: code) {
                self.stopWatching()
                guard self.composer.accentList?.selected != nil, let client = self.client else { return }
                DebugLog.log("held key released with a variant highlighted")
                self.apply(self.composer.chooseHighlightedAccent(), to: client)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        heldWatch = t
    }
    private func stopWatching() { heldWatch?.invalidate(); heldWatch = nil }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        let text = composer.commitAll()
        // Spotlight would drop this, and writing it can leave the field stuck.
        if ClientText.showsOnlyRawKeys(client.bundleIdentifier()) { return }
        if !text.isEmpty { client.insertText(text, replacementRange: noRange) }
    }

    override func activateServer(_ sender: Any!) {
        let incoming = sender as? IMKTextInput
        let bundle = incoming?.bundleIdentifier()
        DebugLog.log("activateServer client=\(bundle ?? "?")")
        // Clicks on Stacker/Symbols are windows of this process. macOS may
        // activate us with ourselves as the client; do not take over document
        // wiring or the insert callbacks in that case.
        let isOurProcess = bundle == Bundle.main.bundleIdentifier
        if isOurProcess {
            StackerPanel.shared.cancelClose()
            SymbolsPanel.shared.cancelClose()
            DictionaryPanel.shared.cancelClose()
            return
        }
        shiftTap.reset()
        composer.reset()
        composer.setPrecomposed(Prefs.precomposed)
        composer.accents = Prefs.accentPalette
        composer.lexicon = Prefs.sanskritSuggestions ? SanskritLexicon.shared : nil
        SuggestionPanel.shared.hide()
        AccentPanel.shared.hide()
        AccentPanel.shared.onPick = { [weak self] i in self?.pickAccent(i) }
        SuggestionPanel.shared.onPick = { [weak self] i in self?.pickSuggestion(i) }
        client = incoming
        if let client = client {
            Self.documentClient = client
            // The lock, else the mode last chosen in any window, else the start setting
            // (the rule is in ttime-core; taps and toolbar clicks are remembered there).
            Self.lock.setStartLatin(Prefs.startLatin)
            apply(composer.setLatin(Self.lock.modeOnFocus), to: client)
        }
        Self.active = self
        let toolbar = Toolbar.shared
        toolbar.chooseMode = { [weak self] latin in self?.toolbarChoose(latin: latin) }
        toolbar.toggleLock = { [weak self] in self?.toolbarToggleLock() }
        toolbar.openStacker = { [weak self] in self?.toggleStacker() }
        toolbar.openSymbols = { [weak self] in self?.toggleSymbols() }
        toolbar.openDictionary = { [weak self] in self?.toggleDictionary() }
        StackerPanel.shared.cancelClose()
        SymbolsPanel.shared.cancelClose()
        DictionaryPanel.shared.cancelClose()
        DictionaryPanel.shared.currentTerm = { [weak self] in self?.termAtCaret() ?? "" }
        // Use the shared document client, not `self.client`, so a later
        // activation for our own process cannot steal inserts.
        StackerPanel.shared.insert = { text in Self.insertIntoDocument(text) }
        SymbolsPanel.shared.insert = { text in Self.insertIntoDocument(text) }
        toolbar.show(toolbarState)
    }

    override func deactivateServer(_ sender: Any!) {
        DebugLog.log("deactivateServer")
        stopWatching()
        SuggestionPanel.shared.hide()
        AccentPanel.shared.hide()
        shiftTap.reset()
        if Self.active === self {
            Toolbar.shared.scheduleHide()
            // Panels stay open until closed (Esc, the close button, or the shortcut).
        }
    }

    /// The input-method menu in the menu bar.
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let item = NSMenuItem(title: Toolbar.isHidden ? "Show Toolbar" : "Hide Toolbar",
                              action: #selector(toggleToolbar(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        menu.addItem(.separator())
        if FileManager.default.fileExists(atPath: "/Applications/T-Time Tools.app") {
            let converter = NSMenuItem(title: "Open Converter…", action: #selector(openConverter(_:)), keyEquivalent: "")
            converter.target = self
            menu.addItem(converter)
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        return menu
    }

    @objc private func openSettings(_ sender: Any?) { SettingsWindow.shared.show() }

    /// Opens T-Time Tools with the current selection (or syllable) as a seed. The text
    /// travels in the URL, which works whether Tools is already running or not and
    /// leaves nothing behind on a shared pasteboard.
    @objc private func openConverter(_ sender: Any?) {
        var comps = URLComponents()
        comps.scheme = "ttime-tools"
        comps.host = "convert"
        let term = String(termAtCaret().prefix(2000))
        if !term.isEmpty { comps.queryItems = [URLQueryItem(name: "text", value: term)] }
        if let url = comps.url { NSWorkspace.shared.open(url) }
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        UpdateManager.shared.check(manual: true) { result in
            guard case .available = result else {
                NSApp.activate(ignoringOtherApps: true)
                let a = NSAlert()
                switch result {
                case .failed:
                    a.messageText = "Could not check for updates"
                    a.informativeText = "The update server could not be reached."
                default:
                    a.messageText = "T-Time is up to date"
                    a.informativeText = "You have the latest version (\(UpdateManager.shared.currentVersion))."
                }
                a.runModal()
                return
            }
        }
    }

    @objc private func toggleToolbar(_ sender: Any?) {
        Toolbar.isHidden.toggle()
        if Toolbar.isHidden { Toolbar.shared.hideNow() } else { Toolbar.shared.show(toolbarState) }
    }

    /// Opens or closes the stacker. What is being typed is fixed first, so the
    /// stack lands after it and nothing is left half-typed.
    private func toggleStacker() {
        if !StackerPanel.shared.isOpen { commitPending() }
        SymbolsPanel.shared.close()
        DictionaryPanel.shared.close()
        StackerPanel.shared.toggle()
    }

    /// The same for the symbols window. Only one of the two is open at a time.
    private func toggleSymbols() {
        if !SymbolsPanel.shared.isOpen { commitPending() }
        StackerPanel.shared.close()
        DictionaryPanel.shared.close()
        SymbolsPanel.shared.toggle()
    }

    /// The same for the dictionary. What is being typed is fixed first, so the
    /// syllable just typed is the one looked up.
    private func toggleDictionary() {
        if !DictionaryPanel.shared.isOpen { commitPending() }
        StackerPanel.shared.close()
        SymbolsPanel.shared.close()
        DictionaryPanel.shared.toggle()
    }

    /// The selected text in the document, else the syllable before the caret.
    /// Not every application can say; then this is empty.
    private func termAtCaret() -> String {
        guard let client = client else { return "" }
        let sel = client.selectedRange()
        guard sel.location != NSNotFound else { return "" }
        if sel.length > 0 {
            return DictionaryLookup.term(selection: client.attributedSubstring(from: sel)?.string, before: nil)
        }
        let n = min(40, sel.location)
        guard n > 0 else { return "" }
        let before = client.attributedSubstring(from: NSRange(location: sel.location - n, length: n))?.string
        return DictionaryLookup.term(selection: nil, before: before)
    }

    private func commitPending() {
        guard let client = client else { return }
        apply(Outcome(insert: composer.commitAll(), marked: "", handled: true), to: client)
    }

    /// Puts tool text (Stacker / Symbols) into the last real document.
    private static func insertIntoDocument(_ text: String) {
        guard !text.isEmpty else { return }
        let noRange = NSRange(location: NSNotFound, length: NSNotFound)
        guard let client = documentClient ?? active?.client else {
            DebugLog.log("insertIntoDocument: no document client")
            return
        }
        DebugLog.log("insertIntoDocument client=\(client.bundleIdentifier() ?? "?") len=\(text.count)")
        // Fix the syllable being typed first, so it is not lost when the marked run is
        // cleared; it goes in ahead of the tool's text.
        let pending = active?.composer.commitAll() ?? ""
        // Clear the marked run; some hosts ignore insertText while one is open.
        client.setMarkedText(NSAttributedString(string: ""),
                             selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: noRange)
        client.insertText(pending + text, replacementRange: noRange)
    }

    private func toolbarChoose(latin: Bool) {
        let latin = Self.lock.choose(latin: latin)
        Self.saveLock()  // a lock follows the mode you chose
        if let client = client {
            apply(composer.setLatin(latin), to: client)
        }
        refreshToolbar()
    }

    private func toolbarToggleLock() {
        Self.lock.toggleLock(isLatin: composer.isLatin)
        Self.saveLock()
        refreshToolbar()
    }

    private func shiftTapped(_ tap: ShiftTapEvent, client: IMKTextInput) {
        switch (tap.side, tap.kind) {
        case (.left, _):
            if let latin = Self.lock.leftTap(tap.kind, isLatin: composer.isLatin) {
                apply(composer.setLatin(latin), to: client)
            }
            if tap.kind == .double { Self.saveLock() }
            refreshToolbar()
        case (.right, .double):
            toggleSymbols()
        case (.right, .single):
            break
        }
    }

    private func keyInput(for event: NSEvent) -> KeyInput {
        let shortcut: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(shortcut).isEmpty { return .other }
        switch event.keyCode {
        case 51: return .backspace
        case 53: return .escape
        case 36, 76: return .enter
        case 48: return .tab
        case 126: return .up
        case 125: return .down
        case 123: return .left
        case 124: return .right
        default: break
        }
        if let chars = event.characters, !chars.isEmpty,
           chars.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value < 0x7F }) {
            return .text(chars)
        }
        return .other
    }

    /// Set only while one key is being handled with the debug log on.
    private var timing: KeyTiming?

    private func apply(_ outcome: Outcome, to client: IMKTextInput) {
        // An empty marked-text update on activation is enough to leave
        // Spotlight's field unable to take keys. Write nothing there.
        if ClientText.showsOnlyRawKeys(client.bundleIdentifier()) {
            SuggestionPanel.shared.hide()
            AccentPanel.shared.hide()
            return
        }
        if !outcome.insert.isEmpty {
            measured(\.insert) {
                if outcome.replacing.isEmpty {
                    client.insertText(outcome.insert, replacementRange: noRange)
                } else if let range = rangeBeforeCaret(matching: outcome.replacing, in: client) {
                    client.insertText(outcome.insert, replacementRange: range)
                } else {
                    // The caret moved since the word was typed (a click, say): leave the text alone.
                    DebugLog.log("replacement skipped: text before the caret is not the typed word")
                }
            }
        }
        // Marked text is shown, or cleared, whenever the key changed it.
        if outcome.handled || !outcome.insert.isEmpty {
            measured(\.mark) {
                client.setMarkedText(NSAttributedString(string: outcome.marked),
                                     selectionRange: NSRange(location: outcome.marked.utf16.count, length: 0),
                                     replacementRange: noRange)
            }
        }
        refreshSuggestions(client)
        refreshAccents(client)
    }

    private func measured(_ stage: ReferenceWritableKeyPath<KeyTiming, Double>, _ body: () -> Void) {
        if let t = timing { t.measure(stage, body) } else { body() }
    }

    /// The range of `typed` just before the caret, if that is what the document holds there.
    private func rangeBeforeCaret(matching typed: String, in client: IMKTextInput) -> NSRange? {
        let caret = client.selectedRange()
        let length = typed.utf16.count
        guard caret.location != NSNotFound, caret.length == 0, caret.location >= length else { return nil }
        let range = NSRange(location: caret.location - length, length: length)
        guard client.attributedSubstring(from: range)?.string == typed else { return nil }
        return range
    }

    /// A click on a Sanskrit suggestion.
    private func pickSuggestion(_ index: Int) {
        guard let client = client else { return }
        apply(composer.chooseSuggestion(index: index), to: client)
    }

    /// A click on a variant in the accent palette.
    private func pickAccent(_ index: Int) {
        guard let client = client else { return }
        apply(composer.chooseAccent(index: index), to: client)
    }

    /// Shows the accent palette above the held letter, or hides it.
    private func refreshAccents(_ client: IMKTextInput) {
        guard let list = composer.accentList else { AccentPanel.shared.hide(); return }
        var rect = NSRect.zero
        measured(\.caret) { _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect) }
        AccentPanel.shared.show(list.options, selected: list.selected, near: rect)
    }

    /// Shows the Sanskrit suggestion list under the word being typed, or hides it.
    private func refreshSuggestions(_ client: IMKTextInput) {
        guard let list = composer.suggestionList else { SuggestionPanel.shared.hide(); return }
        var rect = NSRect.zero
        measured(\.caret) { _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect) }
        measured(\.panel) { SuggestionPanel.shared.show(list.words, selected: list.selected, near: rect) }
    }
}
