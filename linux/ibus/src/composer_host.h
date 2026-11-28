/* Owns the Rust composer and Shift-tap state for one IBus engine (one per input
 * context). The mode lock is shared by every engine in the process, so a lock or the
 * last mode chosen carries over to other windows and applications, as on macOS. The
 * typing rules themselves live in ttime-core. */
#ifndef TTIME_COMPOSER_HOST_H
#define TTIME_COMPOSER_HOST_H

#include <stdbool.h>
#include <stdint.h>

#include "ttime.h"

typedef struct ComposerHost {
    ttime_composer *composer;
    ttime_shift_tap *shift_tap;
    /* The key currently held down (0 for none), to recognise its auto-repeats. */
    uint32_t held_keyval;
} ComposerHost;

void composer_host_init(ComposerHost *h);
void composer_host_destroy(ComposerHost *h);

void composer_host_reset(ComposerHost *h);
/* A field gained focus: forget pending input and start in the locked mode, else the
 * mode last chosen anywhere, else Tibetan. */
void composer_host_on_activate(ComposerHost *h);
/* Caller frees the return value with ttime_string_free. */
char *composer_host_commit_all(ComposerHost *h);

bool composer_host_is_latin(const ComposerHost *h);

/*
 * Maps one IBus key event (press or release) into a ttime_outcome.
 * `keyval` is an IBus keysym; `modifiers` uses IBUS_*_MASK bits, including
 * IBUS_RELEASE_MASK for a release. Returns whether T-Time takes the key; Shift is
 * never taken. The caller applies out->insert / out->marked even when the key is
 * not taken (Return commits, then the application gets it), and frees `out` with
 * ttime_outcome_free.
 */
bool composer_host_handle_key(ComposerHost *h, uint32_t keyval, uint32_t modifiers,
                              ttime_outcome *out);

#endif
