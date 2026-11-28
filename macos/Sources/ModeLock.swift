import Foundation

/// Policy for the left Shift tap: a single tap flips Tibetan/Latin, and the mode is
/// remembered when focus moves to another field or app; a double tap locks the mode
/// you were already in, and a locked mode survives focus changes. While locked, single taps do nothing and a double
/// tap always unlocks, so the lock can never trap the user. The toolbar's mode
/// buttons are never refused: the lock is only against Shift taps.
///
/// The rules live in `ttime-core` (`ttime_mode_lock_*`). The one live instance
/// owns the lock for every client application, so controllers cannot disagree.
final class ModeLock {
    private let ptr: OpaquePointer?

    init(lockedLatin: Bool? = nil) {
        ptr = ttime_mode_lock_new()
        self.lockedLatin = lockedLatin
    }

    deinit { ttime_mode_lock_free(ptr) }

    /// nil: unlocked. true: locked in Latin. false: locked in Tibetan.
    var lockedLatin: Bool? {
        get { Self.mode(ttime_mode_lock_get(ptr)) }
        set { ttime_mode_lock_set(ptr, newValue.map { $0 ? 1 : 0 } ?? -1) }
    }

    /// Sets the mode before any choice (the Settings start mode).
    func setStartLatin(_ latin: Bool) { ttime_mode_lock_set_start_latin(ptr, latin) }

    /// Returns the Latin setting the composer should switch to, or nil to leave
    /// it alone. `isLatin` is the composer's mode *now*, after any earlier tap.
    func leftTap(_ kind: ShiftTapKind, isLatin: Bool) -> Bool? {
        Self.mode(ttime_mode_lock_left_tap(ptr, kind == .single ? 1 : 2, isLatin))
    }

    /// A click on a mode in the toolbar: always allowed. While locked, the lock
    /// follows the mode you chose.
    func choose(latin: Bool) -> Bool { ttime_mode_lock_choose(ptr, latin) }

    /// The toolbar's lock button: locks the current mode, or unlocks.
    func toggleLock(isLatin: Bool) { ttime_mode_lock_toggle_lock(ptr, isLatin) }

    /// The mode a field starts in when it gains focus: the lock, else the mode last
    /// chosen (taps and toolbar clicks are remembered), else `startLatin`.
    var modeOnFocus: Bool { ttime_mode_lock_mode_on_focus(ptr) }

    private static func mode(_ v: Int32) -> Bool? {
        switch v {
        case 0: return false
        case 1: return true
        default: return nil
        }
    }
}
