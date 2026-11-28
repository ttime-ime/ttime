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
/// The timing rules live in `ttime-core` (`ttime_shift_tap_*`); this class only
/// decodes macOS modifier events into presses and releases. Feed it every
/// modifier change and every key press. The caller must never consume the
/// modifier events themselves: the application has to see the Shift release,
/// or it thinks Shift is stuck.
final class ShiftTap {
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

    private let ptr: OpaquePointer?

    init() { ptr = ttime_shift_tap_new() }
    deinit { ttime_shift_tap_free(ptr) }

    /// A key (not a modifier) was pressed: any Shift held now is a chord, and
    /// no pending first tap can pair with a later one.
    func keyDown() { ttime_shift_tap_key_down(ptr) }

    /// Forgets everything, for example when the input source is activated or
    /// deactivated, so a missed release cannot leave a stale press behind.
    func reset() { ttime_shift_tap_reset(ptr) }

    /// A modifier key changed. `flags` is `NSEvent.modifierFlags.rawValue`,
    /// `time` the event timestamp. Returns the tap when one just completed.
    func flagsChanged(keyCode: UInt16, flags: UInt, time: TimeInterval) -> ShiftTapEvent? {
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

        let code: Int32 = side == .left ? 0 : 1
        let bit = side == .left ? Self.leftShiftBit : Self.rightShiftBit
        let chord = flags & Self.chordModifiers != 0
        let thisHeld = ttime_shift_tap_held(ptr, code)
        let otherHeld = ttime_shift_tap_held(ptr, 1 - code)

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
            ttime_shift_tap_press(ptr, code, time, chord, otherHeld)
            return nil
        }
        switch ttime_shift_tap_release(ptr, code, time, chord) {
        case 1: return ShiftTapEvent(side: side, kind: .single)
        case 2: return ShiftTapEvent(side: side, kind: .double)
        default: return nil
        }
    }
}
