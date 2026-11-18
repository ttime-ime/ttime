import Cocoa
import InputMethodKit

/// Connects the system's text input events to a `Composer`. One controller is
/// created per client application.
@objc(TTimeInputController)
final class TTimeInputController: IMKInputController {
    private let composer = Composer()
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

    // Shift taps arrive as modifier changes, not key presses.
    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }
        if event.type == .flagsChanged {
            if let tap = shiftTap.flagsChanged(keyCode: event.keyCode,
                                               flags: UInt(event.modifierFlags.rawValue),
                                               time: event.timestamp) {
                shiftTapped(tap, client: client)
            }
            // Never consume a modifier change: the application must see the
            // Shift release, or it believes Shift is stuck down.
            return false
        }
        guard event.type == .keyDown else { return false }
        shiftTap.keyDown()
        let outcome = composer.handle(keyInput(for: event))
        apply(outcome, to: client)
        return outcome.handled
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        let text = composer.commitAll()
        if !text.isEmpty { client.insertText(text, replacementRange: noRange) }
    }

    override func activateServer(_ sender: Any!) {
        shiftTap.reset()
        composer.reset()
        // A flip made with a single tap lasts until focus moves; a lock stays.
        if let client = sender as? IMKTextInput {
            apply(composer.setLatin(Self.lock.modeOnFocus), to: client)
        }
    }

    override func deactivateServer(_ sender: Any!) {
        shiftTap.reset()
    }

    private func shiftTapped(_ tap: ShiftTapEvent, client: IMKTextInput) {
        switch (tap.side, tap.kind) {
        case (.left, _):
            if let latin = Self.lock.leftTap(tap.kind, isLatin: composer.isLatin) {
                apply(composer.setLatin(latin), to: client)
            }
            if tap.kind == .double { Self.saveLock() }
        case (.right, .double):
            break  // reserved: opens and closes the symbols table, not built yet
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
    }
}
