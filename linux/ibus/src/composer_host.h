/* Owns the Rust composer and shift/mode-lock state for one IBus engine. */
#ifndef TTIME_COMPOSER_HOST_H
#define TTIME_COMPOSER_HOST_H

#include <stdbool.h>
#include <stdint.h>

#include "ttime.h"

typedef struct ComposerHost {
    ttime_composer *composer;
    ttime_shift_tap *shift_tap;
    ttime_mode_lock *mode_lock;
} ComposerHost;

void composer_host_init(ComposerHost *h);
void composer_host_destroy(ComposerHost *h);

void composer_host_reset(ComposerHost *h);
void composer_host_on_activate(ComposerHost *h);
/* Caller frees the return value with ttime_string_free. */
char *composer_host_commit_all(ComposerHost *h);

bool composer_host_is_latin(const ComposerHost *h);

/*
 * Map one IBus key event into a ttime_outcome.
 * `keyval` is an IBus/GDK keysym; `modifiers` uses IBUS_*_MASK bits.
 * Returns whether T-Time ate the key (`out->handled`); Shift is never eaten.
 * Caller must ttime_outcome_free(out).
 */
bool composer_host_handle_key(ComposerHost *h, uint32_t keyval, uint32_t modifiers,
                              bool is_key_down, bool is_repeat, ttime_outcome *out);

#endif
