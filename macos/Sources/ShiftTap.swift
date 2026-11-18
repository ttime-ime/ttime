import Foundation

/// Which Shift key was tapped.
enum ShiftSide: Equatable { case left, right }

/// A tap is `.single`, or `.double` when it is the second of a pair. The first
/// tap of a pair is reported at once as `.single` (nothing waits for a second
/// one), so acting on `.double` has to undo whatever `.single` did.
enum ShiftTapKind: Equatable { case single, double }

struct ShiftTapEvent: Equatable {
    var side: ShiftSide
    var kind: ShiftTapKind
}

/// Recognises a lone Shift tap: a Shift key pressed and released with nothing
/// else in between. Holding Shift for a capital letter is a chord, not a tap.
///
/// A pure state machine, so it can be tested without the system. Feed it every
/// modifier change and every key press; it answers when a tap completes (on
/// release). The caller must never consume the modifier events themselves:
/// the application has to see the Shift release, or it thinks Shift is stuck.
struct ShiftTap {
    /// A press held longer than this is not a tap. This keeps Shift+click and
    /// "hold Shift while thinking" from toggling anything.
    static let maxTapDuration: TimeInterval = 0.35
    /// Two taps of the same Shift this close together are a double tap.
    static let doubleTapWindow: TimeInterval = 0.5

    // Hardware key codes of the two Shift keys.
    static let leftKeyCode: UInt16 = 56
    static let rightKeyCode: UInt16 = 60

    // Bits of NSEvent.modifierFlags.rawValue. macOS may or may not include the
    // device-dependent Shift bits (one per key); an input method has been seen to
    // receive only the generic `shiftMask`, so press and release must also be
    // decidable from that and from which keys are known to be held.
    static let shiftMask: UInt = 1 << 17
    static let leftShiftBit: UInt = 0x2
    static let rightShiftBit: UInt = 0x4
    static let controlBit: UInt = 1 << 18
    static let optionBit: UInt = 1 << 19
    static let commandBit: UInt = 1 << 20
    static let chordModifiers: UInt = controlBit | optionBit | commandBit

    private struct Held {
        var since: TimeInterval
        var spoiled: Bool
    }
    private var left: Held?
    private var right: Held?
    private var lastLeftTap: TimeInterval?
    private var lastRightTap: TimeInterval?

    /// A key (not a modifier) was pressed: any Shift held now is a chord, and
    /// no pending first tap can pair with a later one.
    mutating func keyDown() {
        left?.spoiled = true
        right?.spoiled = true
        lastLeftTap = nil
        lastRightTap = nil
    }

    /// Forgets everything, for example when the input source is activated or
    /// deactivated, so a missed release cannot leave a stale press behind.
    mutating func reset() {
        left = nil
        right = nil
        lastLeftTap = nil
        lastRightTap = nil
    }

    /// A modifier key changed. `flags` is `NSEvent.modifierFlags.rawValue`,
    /// `time` the event timestamp. Returns the tap when one just completed.
    mutating func flagsChanged(keyCode: UInt16, flags: UInt, time: TimeInterval) -> ShiftTapEvent? {
        let side: ShiftSide
        switch keyCode {
        case Self.leftKeyCode: side = .left
        case Self.rightKeyCode: side = .right
        default:
            // Control, Option, Command, Caps Lock or fn changed: a Shift held
            // right now is part of a chord.
            keyDown()
            return nil
        }

        let bit = side == .left ? Self.leftShiftBit : Self.rightShiftBit
        let chord = flags & Self.chordModifiers != 0

        let thisHeld = side == .left ? left != nil : right != nil
        let otherHeld = side == .left ? right != nil : left != nil
        let down: Bool
        if flags & (Self.leftShiftBit | Self.rightShiftBit) != 0 {
            down = flags & bit != 0  // the device bits say exactly which keys are down
        } else if flags & Self.shiftMask == 0 {
            down = false  // no Shift at all is down
        } else {
            // Only the generic bit: with the other Shift down it cannot say which
            // changed, so this key's state toggles; otherwise Shift is now down.
            down = otherHeld ? !thisHeld : true
        }

        if down {
            // Press. If the other Shift is already down, both are a chord.
            if otherHeld { keyDown() }
            let held = Held(since: time, spoiled: chord || otherHeld)
            if side == .left { left = held } else { right = held }
            return nil
        }

        // Release.
        guard let held = (side == .left ? left : right) else { return nil }
        if side == .left { left = nil } else { right = nil }
        let clean = !held.spoiled && !chord && time - held.since <= Self.maxTapDuration
        guard clean else {
            if side == .left { lastLeftTap = nil } else { lastRightTap = nil }
            return nil
        }
        let previous = side == .left ? lastLeftTap : lastRightTap
        if let previous = previous, time - previous <= Self.doubleTapWindow {
            // Second of a pair; a third tap starts a fresh pair.
            if side == .left { lastLeftTap = nil } else { lastRightTap = nil }
            return ShiftTapEvent(side: side, kind: .double)
        }
        if side == .left { lastLeftTap = time } else { lastRightTap = time }
        return ShiftTapEvent(side: side, kind: .single)
    }
}
