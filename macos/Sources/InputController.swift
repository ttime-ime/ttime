import Cocoa
import InputMethodKit

/// Connects the system's text input events to a `Composer`. One controller is
/// created per client application.
@objc(TTimeInputController)
final class TTimeInputController: IMKInputController {
    private let composer = Composer()
    private let noRange = NSRange(location: NSNotFound, length: NSNotFound)

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown,
              let client = sender as? IMKTextInput else { return false }
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
        composer.reset()
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
