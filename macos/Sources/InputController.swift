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
    /// The mode last chosen in any window, so switching windows keeps it. Nil until
    /// the first choice, when the Settings start mode applies.
    private static var lastLatin: Bool?
    private func rememberMode() { Self.lastLatin = composer.isLatin }
    private let noRange = NSRange(location: NSNotFound, length: NSNotFound)

    /// The controller whose client currently has focus; the toolbar acts on it.
    private static weak var active: TTimeInputController?
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
        if StackerPanel.shared.isOpen {
            if StackerPanel.shared.handle(keyInput(for: event)) { return true }
        } else if SymbolsPanel.shared.isOpen {
            if SymbolsPanel.shared.handle(keyInput(for: event)) { return true }
        }
        let outcome = composer.handle(keyInput(for: event), isRepeat: event.isARepeat)
        apply(outcome, to: client)
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
        if !text.isEmpty { client.insertText(text, replacementRange: noRange) }
    }

    override func activateServer(_ sender: Any!) {
        DebugLog.log("activateServer client=\((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")
        shiftTap.reset()
        composer.reset()
        composer.setPrecomposed(Prefs.precomposed)
        composer.accents = Prefs.accentPalette
        composer.suggester = Prefs.sanskritSuggestions ? SanskritLexicon.shared.map { SanskritSuggester(lexicon: $0) } : nil
        SuggestionPanel.shared.hide()
        AccentPanel.shared.hide()
        AccentPanel.shared.onPick = { [weak self] i in self?.pickAccent(i) }
        SuggestionPanel.shared.onPick = { [weak self] i in self?.pickSuggestion(i) }
        client = sender as? IMKTextInput
        // The mode carries over from window to window; a lock overrides it.
        if let client = client {
            apply(composer.setLatin(Self.lock.lockedLatin ?? Self.lastLatin ?? Prefs.startLatin), to: client)
            rememberMode()
        }
        Self.active = self
        let toolbar = Toolbar.shared
        toolbar.chooseMode = { [weak self] latin in self?.toolbarChoose(latin: latin) }
        toolbar.toggleLock = { [weak self] in self?.toolbarToggleLock() }
        toolbar.openStacker = { [weak self] in self?.toggleStacker() }
        toolbar.openSymbols = { [weak self] in self?.toggleSymbols() }
        StackerPanel.shared.cancelClose()
        SymbolsPanel.shared.cancelClose()
        StackerPanel.shared.insert = { [weak self] text in self?.insertFromTool(text) }
        SymbolsPanel.shared.insert = { [weak self] text in self?.insertFromTool(text) }
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
            StackerPanel.shared.scheduleClose()
            SymbolsPanel.shared.scheduleClose()
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
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        return menu
    }

    @objc private func openSettings(_ sender: Any?) { SettingsWindow.shared.show() }

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
        StackerPanel.shared.toggle()
    }

    /// The same for the symbols window. Only one of the two is open at a time.
    private func toggleSymbols() {
        if !SymbolsPanel.shared.isOpen { commitPending() }
        StackerPanel.shared.close()
        SymbolsPanel.shared.toggle()
    }

    private func commitPending() {
        guard let client = client else { return }
        apply(Outcome(insert: composer.commitAll(), marked: "", handled: true), to: client)
    }

    private func insertFromTool(_ text: String) {
        client?.insertText(text, replacementRange: noRange)
    }

    private func toolbarChoose(latin: Bool) {
        if let latin = Self.lock.choose(latin: latin), let client = client {
            apply(composer.setLatin(latin), to: client)
            rememberMode()
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
                rememberMode()
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

    private func apply(_ outcome: Outcome, to client: IMKTextInput) {
        if !outcome.insert.isEmpty {
            client.insertText(outcome.insert, replacementRange: noRange)
        }
        // Marked text is shown, or cleared, whenever the key changed it.
        if outcome.handled || !outcome.insert.isEmpty {
            client.setMarkedText(NSAttributedString(string: outcome.marked),
                                 selectionRange: NSRange(location: outcome.marked.utf16.count, length: 0),
                                 replacementRange: noRange)
        }
        refreshSuggestions(client)
        refreshAccents(client)
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
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        AccentPanel.shared.show(list.options, selected: list.selected, near: rect)
    }

    /// Shows the Sanskrit suggestion list under the word being typed, or hides it.
    private func refreshSuggestions(_ client: IMKTextInput) {
        guard let list = composer.suggestionList else { SuggestionPanel.shared.hide(); return }
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        SuggestionPanel.shared.show(list.words, selected: list.selected, near: rect)
    }
}
