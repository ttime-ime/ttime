import Foundation

/// Policy for the left Shift tap: a single tap flips Tibetan/Latin until focus
/// moves on; a double tap locks the mode you were already in, and a locked mode
/// survives focus changes. While locked, single taps do nothing and a double
/// tap always unlocks, so the lock can never trap the user.
///
/// Pure, so it is testable. The one live instance owns the lock for every
/// client application, so controllers cannot disagree about it.
struct ModeLock: Equatable {
    /// nil: unlocked. true: locked in Latin. false: locked in Tibetan.
    var lockedLatin: Bool?

    /// Returns the Latin setting the composer should switch to, or nil to leave
    /// it alone. `isLatin` is the composer's mode *now*, after any earlier tap.
    mutating func leftTap(_ kind: ShiftTapKind, isLatin: Bool) -> Bool? {
        switch kind {
        case .single:
            return lockedLatin == nil ? !isLatin : nil
        case .double:
            if lockedLatin != nil {
                lockedLatin = nil
                return nil
            }
            // The first tap of the pair already flipped the mode: flip it back
            // and lock the mode the user was in.
            let original = !isLatin
            lockedLatin = original
            return original
        }
    }

    /// The mode a client starts in when it gains focus.
    var modeOnFocus: Bool { lockedLatin ?? false }
}
