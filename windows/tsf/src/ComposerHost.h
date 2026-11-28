#pragma once

#include <windows.h>

#include "ttime.h"

// Owns the Rust composer and Shift-tap / mode-lock state for one text service
// instance (TSF creates one per thread). Decodes Windows keys into the C ABI;
// the typing rules themselves live in ttime-core.
class ComposerHost {
public:
    ComposerHost();
    ~ComposerHost();

    ComposerHost(const ComposerHost &) = delete;
    ComposerHost &operator=(const ComposerHost &) = delete;

    // Forgets pending input (the application ended the composition).
    void Reset();
    // A document gained focus: forget pending input and pick the starting mode.
    void OnActivate();
    // Commits pending input; returns UTF-8 to insert (free with ttime_string_free).
    char *CommitAll();

    // One key event. Returns true when T-Time takes the key; `out` always gets an
    // outcome (free it with ttime_outcome_free), whose insert/marked the caller applies
    // even when the key is not taken (Return commits, then the application gets it).
    bool HandleKey(WPARAM wParam, LPARAM lParam, bool isKeyDown, ttime_outcome *out);

    bool IsLatin() const;

private:
    ttime_composer *composer_ = nullptr;
    ttime_shift_tap *shiftTap_ = nullptr;
    ttime_mode_lock *modeLock_ = nullptr;

    bool HandleShift(bool left, bool isKeyDown, double timeSec, ttime_outcome *out);
};
