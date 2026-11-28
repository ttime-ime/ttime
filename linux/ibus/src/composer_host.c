#include "composer_host.h"

#include <ibus.h>

/* --- The shared mode lock -------------------------------------------------------
 * One per process: IBus runs a single engine process and creates an engine object per
 * input context. The lock and the last mode are also saved, so they survive restarts
 * (macOS keeps its lock the same way), in $XDG_CONFIG_HOME/t-time/ibus.ini. */

static ttime_mode_lock *mode_lock = NULL;

static char *mode_file(void) {
    return g_build_filename(g_get_user_config_dir(), "t-time", "ibus.ini", NULL);
}

static ttime_mode_lock *shared_mode_lock(void) {
    if (mode_lock) return mode_lock;
    mode_lock = ttime_mode_lock_new();
    char *path = mode_file();
    GKeyFile *kf = g_key_file_new();
    if (g_key_file_load_from_file(kf, path, G_KEY_FILE_NONE, NULL)) {
        GError *err = NULL;
        int lock = g_key_file_get_integer(kf, "mode", "lock", &err);
        if (!err) ttime_mode_lock_set(mode_lock, lock);
        g_clear_error(&err);
        int last = g_key_file_get_integer(kf, "mode", "last", &err);
        if (!err) ttime_mode_lock_set_last(mode_lock, last);
        g_clear_error(&err);
        int start = g_key_file_get_integer(kf, "mode", "start", &err);
        if (!err) ttime_mode_lock_set_start_latin(mode_lock, start == 1);
        g_clear_error(&err);
    }
    g_key_file_unref(kf);
    g_free(path);
    return mode_lock;
}

/* Values are -1 none, 0 Tibetan, 1 Latin, as in ttime.h. */
static void save_mode(void) {
    char *path = mode_file();
    char *dir = g_path_get_dirname(path);
    g_mkdir_with_parents(dir, 0700);
    GKeyFile *kf = g_key_file_new();
    g_key_file_load_from_file(kf, path, G_KEY_FILE_KEEP_COMMENTS, NULL);  /* keep "start" */
    g_key_file_set_integer(kf, "mode", "lock", ttime_mode_lock_get(mode_lock));
    g_key_file_set_integer(kf, "mode", "last", ttime_mode_lock_get_last(mode_lock));
    if (!g_key_file_save_to_file(kf, path, NULL)) g_warning("T-Time: could not save %s", path);
    g_key_file_unref(kf);
    g_free(dir);
    g_free(path);
}

/* --- Keys ---------------------------------------------------------------------- */

static double now_sec(void) { return (double)g_get_monotonic_time() / 1e6; }

/* Modifier and lock keys on their own: they change no text and must not commit. */
static bool is_modifier_only(uint32_t keyval) {
    switch (keyval) {
    case IBUS_KEY_Control_L: case IBUS_KEY_Control_R:
    case IBUS_KEY_Alt_L: case IBUS_KEY_Alt_R:
    case IBUS_KEY_Meta_L: case IBUS_KEY_Meta_R:
    case IBUS_KEY_Super_L: case IBUS_KEY_Super_R:
    case IBUS_KEY_Hyper_L: case IBUS_KEY_Hyper_R:
    case IBUS_KEY_ISO_Level3_Shift:
    case IBUS_KEY_Caps_Lock: case IBUS_KEY_Num_Lock: case IBUS_KEY_Scroll_Lock:
        return true;
    default:
        return false;
    }
}

static const guint kChordMask =
    IBUS_CONTROL_MASK | IBUS_MOD1_MASK | IBUS_MOD4_MASK | IBUS_SUPER_MASK | IBUS_META_MASK;

/* Maps a keysym to a TTIME_KEY_* kind; for TTIME_KEY_TEXT writes one character. */
static int map_key(uint32_t keyval, uint32_t modifiers, char *utf8, int utf8_cap) {
    switch (keyval) {
    case IBUS_KEY_BackSpace: return TTIME_KEY_BACKSPACE;
    case IBUS_KEY_Escape: return TTIME_KEY_ESCAPE;
    case IBUS_KEY_Return: case IBUS_KEY_KP_Enter: return TTIME_KEY_ENTER;
    case IBUS_KEY_Tab: case IBUS_KEY_ISO_Left_Tab: return TTIME_KEY_TAB;
    case IBUS_KEY_Up: return TTIME_KEY_UP;
    case IBUS_KEY_Down: return TTIME_KEY_DOWN;
    case IBUS_KEY_Left: return TTIME_KEY_LEFT;
    case IBUS_KEY_Right: return TTIME_KEY_RIGHT;
    default: break;
    }

    /* Shortcuts belong to the application. Ctrl+Alt together is AltGr on some
     * layouts, which types characters, so it is judged by the keysym. */
    const bool ctrl = (modifiers & IBUS_CONTROL_MASK) != 0;
    const bool alt = (modifiers & IBUS_MOD1_MASK) != 0;
    if (modifiers & (IBUS_MOD4_MASK | IBUS_SUPER_MASK | IBUS_META_MASK)) return TTIME_KEY_OTHER;
    if ((ctrl || alt) && !(ctrl && alt)) return TTIME_KEY_OTHER;

    /* EWTS is ASCII, and an ASCII keysym is its own code point. Anything else (other
     * layouts' letters, keypad keys, Delete) commits and goes to the application. */
    if (keyval >= 0x20 && keyval <= 0x7e && utf8_cap >= 2) {
        utf8[0] = (char)keyval;
        utf8[1] = 0;
        return TTIME_KEY_TEXT;
    }
    return TTIME_KEY_OTHER;
}

void composer_host_init(ComposerHost *h) {
    h->composer = ttime_composer_new(false);
    h->shift_tap = ttime_shift_tap_new();
    h->held_keyval = 0;
    (void)shared_mode_lock();
}

void composer_host_destroy(ComposerHost *h) {
    ttime_composer_free(h->composer);
    ttime_shift_tap_free(h->shift_tap);
    h->composer = NULL;
    h->shift_tap = NULL;
    /* The shared mode lock lives as long as the process. */
}

void composer_host_reset(ComposerHost *h) {
    ttime_composer_reset(h->composer);
    ttime_shift_tap_reset(h->shift_tap);
    h->held_keyval = 0;
}

void composer_host_on_activate(ComposerHost *h) {
    composer_host_reset(h);
    ttime_outcome o =
        ttime_composer_set_latin(h->composer, ttime_mode_lock_mode_on_focus(shared_mode_lock()));
    ttime_outcome_free(&o);
}

char *composer_host_commit_all(ComposerHost *h) { return ttime_composer_commit_all(h->composer); }

bool composer_host_is_latin(const ComposerHost *h) { return ttime_composer_is_latin(h->composer); }

static bool handle_shift(ComposerHost *h, bool left, bool is_key_down, uint32_t modifiers,
                         ttime_outcome *out) {
    const int side = left ? 0 : 1;
    const bool chord = (modifiers & kChordMask) != 0;
    const double t = now_sec();
    if (is_key_down) {
        /* An auto-repeat of a Shift already down is not a new press. */
        if (!ttime_shift_tap_held(h->shift_tap, side)) {
            ttime_shift_tap_press(h->shift_tap, side, t, chord,
                                  ttime_shift_tap_held(h->shift_tap, 1 - side));
        }
        return false;
    }
    const int kind = ttime_shift_tap_release(h->shift_tap, side, t, chord);
    if (kind != 0 && left) {
        ttime_mode_lock *lock = shared_mode_lock();
        const int want = ttime_mode_lock_left_tap(lock, kind, ttime_composer_is_latin(h->composer));
        if (want >= 0) *out = ttime_composer_set_latin(h->composer, want == 1);
        save_mode();  /* the last mode, and a lock set or cleared by a double tap */
    }
    return false;  /* the application sees every Shift event */
}

bool composer_host_handle_key(ComposerHost *h, uint32_t keyval, uint32_t modifiers,
                              ttime_outcome *out) {
    *out = (ttime_outcome){0};
    const bool is_key_down = (modifiers & IBUS_RELEASE_MASK) == 0;

    if (keyval == IBUS_KEY_Shift_L || keyval == IBUS_KEY_Shift_R) {
        return handle_shift(h, keyval == IBUS_KEY_Shift_L, is_key_down, modifiers, out);
    }
    if (!is_key_down) {
        if (keyval == h->held_keyval) h->held_keyval = 0;
        return false;
    }

    /* Any other key, modifiers included, means a Shift held now is a chord. */
    ttime_shift_tap_key_down(h->shift_tap);
    if (is_modifier_only(keyval)) return false;

    /* IBus has no repeat flag: a press of the key already held, with no release in
     * between, is an auto-repeat (a long press, which opens the accent palette). */
    const bool repeat = keyval == h->held_keyval;
    h->held_keyval = keyval;

    char utf8[8] = {0};
    const int kind = map_key(keyval, modifiers, utf8, (int)sizeof(utf8));
    *out = ttime_composer_handle(h->composer, kind, kind == TTIME_KEY_TEXT ? utf8 : NULL, repeat);
    return out->handled;
}
