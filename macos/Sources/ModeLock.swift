import Foundation

/// Policy for the left Shift tap: a single tap flips Tibetan/Latin until focus
/// moves on; a double tap locks the mode you were already in, and a locked mode
/// survives focus changes. While locked, single taps do nothing and a double
/// tap always unlocks, so the lock can never trap the user. The toolbar's mode
/// buttons are never refused: the lock is only against Shift taps.
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

    /// A click on a mode in the toolbar: always allowed. The lock only stops Shift
    /// taps, so a click while locked changes the mode and the lock follows it (it now
    /// holds the mode you chose, across fields and apps, until you unlock).
    mutating func choose(latin: Bool) -> Bool {
        if lockedLatin != nil { lockedLatin = latin }
        return latin
    }

    /// The toolbar's lock button: locks the current mode, or unlocks.
    mutating func toggleLock(isLatin: Bool) {
        lockedLatin = lockedLatin == nil ? isLatin : nil
    }

    /// The mode a client starts in when it gains focus.
    var modeOnFocus: Bool { lockedLatin ?? false }
}
