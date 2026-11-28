#include "composer_host.h"

#include <string.h>
#include <time.h>

/* IBus/GDK keysyms and modifier masks (numeric values are stable). */
#define IBUS_Control_L 0xffe3
#define IBUS_Control_R 0xffe4
#define IBUS_Shift_L 0xffe1
#define IBUS_Shift_R 0xffe2
#define IBUS_Alt_L 0xffe9
#define IBUS_Alt_R 0xffea
#define IBUS_Meta_L 0xffe7
#define IBUS_Meta_R 0xffe8
#define IBUS_Super_L 0xffeb
#define IBUS_Super_R 0xffec
#define IBUS_Hyper_L 0xffed
#define IBUS_Hyper_R 0xffee
#define IBUS_Caps_Lock 0xffe5
#define IBUS_Num_Lock 0xff7f
#define IBUS_Scroll_Lock 0xff14
#define IBUS_BackSpace 0xff08
#define IBUS_Escape 0xff1b
#define IBUS_Return 0xff0d
#define IBUS_KP_Enter 0xff8d
#define IBUS_Tab 0xff09
#define IBUS_ISO_Left_Tab 0xfe20
#define IBUS_Up 0xff52
#define IBUS_Down 0xff54
#define IBUS_Left 0xff51
#define IBUS_Right 0xff53
#define IBUS_space 0x020
#define IBUS_Delete 0xffff

#define IBUS_SHIFT_MASK (1 << 0)
#define IBUS_LOCK_MASK (1 << 1)
#define IBUS_CONTROL_MASK (1 << 2)
#define IBUS_MOD1_MASK (1 << 3)
#define IBUS_MOD4_MASK (1 << 6)
#define IBUS_SUPER_MASK (1 << 26)
#define IBUS_META_MASK (1 << 28)
#define IBUS_RELEASE_MASK (1 << 30)

static ttime_outcome empty_outcome(void) {
    ttime_outcome o = {0};
    o.handled = false;
    return o;
}

static double now_sec(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0.0;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static bool is_modifier_only(uint32_t keyval) {
    switch (keyval) {
    case IBUS_Control_L:
    case IBUS_Control_R:
    case IBUS_Alt_L:
    case IBUS_Alt_R:
    case IBUS_Meta_L:
    case IBUS_Meta_R:
    case IBUS_Super_L:
    case IBUS_Super_R:
    case IBUS_Hyper_L:
    case IBUS_Hyper_R:
    case IBUS_Caps_Lock:
    case IBUS_Num_Lock:
    case IBUS_Scroll_Lock:
        return true;
    default:
        return false;
    }
}

static bool chord_from_modifiers(uint32_t modifiers) {
    return (modifiers & (IBUS_CONTROL_MASK | IBUS_MOD1_MASK | IBUS_MOD4_MASK | IBUS_SUPER_MASK |
                         IBUS_META_MASK)) != 0;
}

/* Map keyval to TTIME_KEY_*; for TEXT, write one UTF-8 character into utf8. */
static int map_key(uint32_t keyval, uint32_t modifiers, char *utf8, int utf8_cap) {
    switch (keyval) {
    case IBUS_BackSpace:
        return TTIME_KEY_BACKSPACE;
    case IBUS_Escape:
        return TTIME_KEY_ESCAPE;
    case IBUS_Return:
    case IBUS_KP_Enter:
        return TTIME_KEY_ENTER;
    case IBUS_Tab:
    case IBUS_ISO_Left_Tab:
        return TTIME_KEY_TAB;
    case IBUS_Up:
        return TTIME_KEY_UP;
    case IBUS_Down:
        return TTIME_KEY_DOWN;
    case IBUS_Left:
        return TTIME_KEY_LEFT;
    case IBUS_Right:
        return TTIME_KEY_RIGHT;
    default:
        break;
    }

    /* Shortcuts belong to the app. Ctrl+Alt (AltGr) may type characters. */
    const bool ctrl = (modifiers & IBUS_CONTROL_MASK) != 0;
    const bool alt = (modifiers & IBUS_MOD1_MASK) != 0;
    const bool super = (modifiers & (IBUS_MOD4_MASK | IBUS_SUPER_MASK | IBUS_META_MASK)) != 0;
    if (super) return TTIME_KEY_OTHER;
    if ((ctrl || alt) && !(ctrl && alt)) return TTIME_KEY_OTHER;

    /* Printable Latin-1 / ASCII from the keysym value itself (EWTS uses US-layout
     * characters). IBus keyvals for ASCII equal the Unicode code point. */
    if (keyval >= 0x20 && keyval <= 0x7e) {
        if (utf8_cap < 2) return TTIME_KEY_OTHER;
        utf8[0] = (char)keyval;
        utf8[1] = 0;
        return TTIME_KEY_TEXT;
    }

    /* Ignore Delete and other non-text keys as OTHER (commit + pass through). */
    (void)IBUS_Delete;
    (void)IBUS_space;
    (void)IBUS_LOCK_MASK;
    (void)IBUS_SHIFT_MASK;
    (void)IBUS_RELEASE_MASK;
    return TTIME_KEY_OTHER;
}

void composer_host_init(ComposerHost *h) {
    if (!h) return;
    h->composer = ttime_composer_new(false);
    h->shift_tap = ttime_shift_tap_new();
    h->mode_lock = ttime_mode_lock_new();
}

void composer_host_destroy(ComposerHost *h) {
    if (!h) return;
    ttime_composer_free(h->composer);
    ttime_shift_tap_free(h->shift_tap);
    ttime_mode_lock_free(h->mode_lock);
    h->composer = NULL;
    h->shift_tap = NULL;
    h->mode_lock = NULL;
}

void composer_host_reset(ComposerHost *h) {
    if (!h) return;
    ttime_composer_reset(h->composer);
    ttime_shift_tap_reset(h->shift_tap);
}

void composer_host_on_activate(ComposerHost *h) {
    if (!h) return;
    composer_host_reset(h);
    ttime_outcome o = ttime_composer_set_latin(h->composer, ttime_mode_lock_mode_on_focus(h->mode_lock));
    ttime_outcome_free(&o);
}

char *composer_host_commit_all(ComposerHost *h) {
    if (!h) return NULL;
    return ttime_composer_commit_all(h->composer);
}

bool composer_host_is_latin(const ComposerHost *h) {
    return h && ttime_composer_is_latin(h->composer);
}

static bool handle_shift(ComposerHost *h, bool left, bool is_key_down, double time_sec,
                         uint32_t modifiers, ttime_outcome *out) {
    const int side = left ? 0 : 1;
    const bool chord = chord_from_modifiers(modifiers);
    *out = empty_outcome();
    if (is_key_down) {
        if (!ttime_shift_tap_held(h->shift_tap, side)) {
            ttime_shift_tap_press(h->shift_tap, side, time_sec, chord,
                                  ttime_shift_tap_held(h->shift_tap, 1 - side));
        }
        return false;
    }
    const int kind = ttime_shift_tap_release(h->shift_tap, side, time_sec, chord);
    if (kind != 0 && left) {
        const int want =
            ttime_mode_lock_left_tap(h->mode_lock, kind, ttime_composer_is_latin(h->composer));
        if (want >= 0) *out = ttime_composer_set_latin(h->composer, want == 1);
    }
    return false;
}

bool composer_host_handle_key(ComposerHost *h, uint32_t keyval, uint32_t modifiers,
                              bool is_key_down, bool is_repeat, ttime_outcome *out) {
    if (!h || !out) return false;
    *out = empty_outcome();
    const double time_sec = now_sec();

    if (keyval == IBUS_Shift_L || keyval == IBUS_Shift_R) {
        return handle_shift(h, keyval == IBUS_Shift_L, is_key_down, time_sec, modifiers, out);
    }

    if (!is_key_down) return false;

    ttime_shift_tap_key_down(h->shift_tap);
    if (is_modifier_only(keyval)) return false;

    char utf8[8] = {0};
    const int kind = map_key(keyval, modifiers, utf8, (int)sizeof(utf8));
    *out = ttime_composer_handle(h->composer, kind, kind == TTIME_KEY_TEXT ? utf8 : NULL, is_repeat);
    return out->handled;
}
