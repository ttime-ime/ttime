/* C interface to the T-Time engine. Strings are UTF-8 and NUL-terminated.
 * Every `char *` returned by this library is owned by the caller and must be
 * released with ttime_string_free(). A NULL session or NULL text argument is
 * treated as empty and never crashes. */
#ifndef TTIME_H
#define TTIME_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ttime_session ttime_session;

/* Engine version, e.g. "0.1.0". */
char *ttime_version(void);

ttime_session *ttime_session_new(bool precomposed);
void ttime_session_free(ttime_session *s);

/* Feed typed characters; a space or newline commits the provisional run
 * (except inside [...] or after a backslash). */
void ttime_session_insert(ttime_session *s, const char *utf8);

/* Remove the last provisional keystroke. Returns false, changing nothing, when
 * there is no provisional text (the host should then edit its own text). */
bool ttime_session_backspace(ttime_session *s);

/* Drop the provisional run. */
void ttime_session_cancel(ttime_session *s);

/* Tibetan text for the provisional run: show it as marked text. */
char *ttime_session_provisional(const ttime_session *s);

/* EWTS typed since the last commit. */
char *ttime_session_raw(const ttime_session *s);

/* True while a provisional run exists. */
bool ttime_session_has_provisional(const ttime_session *s);

/* Return text committed since the last call, and forget it. */
char *ttime_session_take_committed(ttime_session *s);

/* Commit the provisional run and return everything committed since the last
 * take (use when the user presses Return or the field loses focus). */
char *ttime_session_finish(ttime_session *s);

/* Latin mode: typed text passes through unchanged (no EWTS, a space is a
 * space). Switching either way first fixes the provisional run; collect it with
 * ttime_session_take_committed(). */
void ttime_session_set_latin(ttime_session *s, bool on);
bool ttime_session_is_latin(const ttime_session *s);

/* The stack builder. `layers` are consonant keys separated by spaces, top to
 * bottom ("k Sh"); `vowel` is a key or "" for the inherent a; `marks` are keys
 * separated by spaces. Returns JSON:
 *   {"ok":true,"text":...,"canonical":...,"shortest":...,"codePoints":...,
 *    "diagnostics":[{"severity":...,"message":...,...}]}
 * or {"ok":false,"error":...}. `shortest` is the shortest EWTS that gives the
 * same text (rgya for r+g+ya). */
char *ttime_build_stack_json(const char *layers, const char *vowel, const char *marks,
                             bool precomposed);

/* Every letter, vowel and mark the builder accepts, with an example of each:
 *   {"consonants":[{"key":...,"example":...}],"subjoinedOnly":[...],
 *    "vowels":[...],"marks":[...]} */
char *ttime_stack_alphabet_json(void);

/* The symbol catalogue (punctuation, marks, Sanskrit letters). `query` is "" or
 * NULL for all, else matched by name, code point, EWTS or the character.
 * JSON array: [{"id","category","text","ewts"(or null),"name","label","note",
 * "evidence","codePoints"}]. */
char *ttime_symbols_json(const char *query);

/* Category names in order of first appearance, as a JSON array of strings. */
char *ttime_symbol_categories_json(void);

/* Whole-string EWTS → Unicode. `precomposed` matches the IME preference. */
char *ttime_convert(const char *utf8, bool precomposed);

/* Whole-string Unicode → EWTS (lossy where the engine cannot round-trip). */
char *ttime_unicode_to_ewts(const char *utf8);

/* ------------------------------------------------------------------------
 * IME policy shared by every platform shell (macOS, Windows, Linux). Shells
 * decode OS events, call these, and draw; behaviour lives here. Each object is
 * created with *_new, released with *_free, and is not thread-safe: use one
 * from one thread at a time. NULL objects are harmless, as above.
 * ------------------------------------------------------------------------ */

/* What the host should do after a key. The three strings are owned by the
 * caller and never NULL; release them with ttime_outcome_free(), which also
 * sets them to NULL (freeing twice is harmless).
 *   insert    text to put into the document (possibly "")
 *   marked    the whole provisional run to show as marked text; "" clears it
 *   replacing typed text just before the caret that `insert` takes the place
 *             of (a Sanskrit word being completed, or a letter given an
 *             accent); "" when `insert` goes at the caret as it is
 *   handled   whether T-Time consumed the key; if false the application gets it */
typedef struct ttime_outcome {
    char *insert;
    char *marked;
    char *replacing;
    bool handled;
} ttime_outcome;

void ttime_outcome_free(ttime_outcome *o);

/* --- Sanskrit word list --- */

typedef struct ttime_lexicon ttime_lexicon;

/* Parses `word<TAB>count<TAB>flag` lines (the bundled iast-lexicon.tsv). This
 * takes ~100 ms for the full list: call it once, off the UI thread, and give
 * the result to every composer. Safe to free once composers hold it. */
ttime_lexicon *ttime_lexicon_new(const uint8_t *bytes, size_t len);
void ttime_lexicon_free(ttime_lexicon *l);
size_t ttime_lexicon_len(const ttime_lexicon *l);

/* --- Composer: the IME key policy --- */

typedef struct ttime_composer ttime_composer;

/* Key kinds for ttime_composer_handle. TEXT carries `text` (all of ASCII is
 * EWTS input); for the others `text` is ignored and may be NULL. OTHER is any
 * key T-Time does not handle (shortcuts, Home, …): pending text is committed,
 * then the application gets the key. */
enum {
    TTIME_KEY_TEXT = 0,
    TTIME_KEY_BACKSPACE = 1,
    TTIME_KEY_ESCAPE = 2,
    TTIME_KEY_ENTER = 3,
    TTIME_KEY_TAB = 4,
    TTIME_KEY_UP = 5,
    TTIME_KEY_DOWN = 6,
    TTIME_KEY_LEFT = 7,
    TTIME_KEY_RIGHT = 8,
    TTIME_KEY_OTHER = 9
};

ttime_composer *ttime_composer_new(bool precomposed);
void ttime_composer_free(ttime_composer *c);

/* Switches the output form. Anything being typed is dropped, so call it only
 * between compositions (when focus arrives). The Tibetan/Latin mode is kept. */
void ttime_composer_set_precomposed(ttime_composer *c, bool on);

/* Long-press accents in Latin mode: holding a letter offers its IAST variants. */
void ttime_composer_set_accents(ttime_composer *c, bool on);
bool ttime_composer_accents(const ttime_composer *c);

/* Sanskrit suggestions in Latin mode; NULL turns them off. The composer keeps
 * its own reference to the list. Set it between words (it forgets the word
 * being typed). */
void ttime_composer_set_lexicon(ttime_composer *c, const ttime_lexicon *lex);
bool ttime_composer_has_suggester(const ttime_composer *c);

/* One key. `is_repeat` is true for the auto-repeats of a held key (a long
 * press opens the accent palette). */
ttime_outcome ttime_composer_handle(ttime_composer *c, int key_kind, const char *text,
                                    bool is_repeat);

/* A click on suggestion `index`; nothing happens (handled false) without a list. */
ttime_outcome ttime_composer_choose_suggestion(ttime_composer *c, int index);
/* A click on accent variant `index`; nothing happens when the palette is closed. */
ttime_outcome ttime_composer_choose_accent(ttime_composer *c, int index);
/* The held key was let go: picks the highlighted variant, if any. Shells with
 * no key-release event (macOS input methods) poll the key state for this. */
ttime_outcome ttime_composer_choose_highlighted_accent(ttime_composer *c);

/* Switches between Tibetan and Latin. Pending text is fixed first and comes
 * back as `insert`; the marked text is cleared. */
ttime_outcome ttime_composer_set_latin(ttime_composer *c, bool on);
bool ttime_composer_is_latin(const ttime_composer *c);

/* Commits anything pending and returns all text not yet inserted (focus lost). */
char *ttime_composer_commit_all(ttime_composer *c);
/* Forgets pending input, for example when the input source is activated. */
void ttime_composer_reset(ttime_composer *c);

/* The suggestion list to draw, or NULL when there is none:
 *   {"words":[...],"selected":n,"buffer":"praj"}
 * `words` are capitalised like the typed word; `buffer` is that word, already
 * in the document. */
char *ttime_composer_suggestion_json(const ttime_composer *c);
/* The accent palette to draw, or NULL when it is closed:
 *   {"options":["ṛ","ṝ"],"selected":n|null}
 * `selected` is null until an arrow or Tab moves onto a variant. */
char *ttime_composer_accent_json(const ttime_composer *c);
/* The Latin word being typed (for suggestions), or "". */
char *ttime_composer_suggestion_buffer(const ttime_composer *c);

/* --- Mode lock: left-Shift tap policy --- */

/* A single tap flips Tibetan/Latin; a double tap locks the mode the user was in;
 * while locked, single taps do nothing and a double tap unlocks. Toolbar clicks are
 * never refused. A field gaining focus starts in the locked mode, else the mode last
 * chosen (by a tap or a click, in any field), else the start mode. Keep one instance
 * for every client so they cannot disagree; a shell whose clients are separate
 * processes (Windows) saves lock and last mode and loads them on focus.
 * Lock and last-mode values: -1 none, 0 Tibetan, 1 Latin. */
typedef struct ttime_mode_lock ttime_mode_lock;

ttime_mode_lock *ttime_mode_lock_new(void);
void ttime_mode_lock_free(ttime_mode_lock *m);
void ttime_mode_lock_set(ttime_mode_lock *m, int locked);
int ttime_mode_lock_get(const ttime_mode_lock *m);
void ttime_mode_lock_set_last(ttime_mode_lock *m, int last);
int ttime_mode_lock_get_last(const ttime_mode_lock *m);
/* The mode before any choice (a setting; false, Tibetan, by default). */
void ttime_mode_lock_set_start_latin(ttime_mode_lock *m, bool latin);
/* `kind` as returned by ttime_shift_tap_release (1 single, 2 double); `is_latin`
 * is the mode now, after any earlier tap. Returns the mode to switch to (0
 * Tibetan, 1 Latin) or -1 to leave it alone. */
int ttime_mode_lock_left_tap(ttime_mode_lock *m, int kind, bool is_latin);
/* A toolbar click on a mode: returns `latin` and remembers it; while locked the lock
 * follows it. */
bool ttime_mode_lock_choose(ttime_mode_lock *m, bool latin);
/* The toolbar lock button: locks the current mode, or unlocks. */
void ttime_mode_lock_toggle_lock(ttime_mode_lock *m, bool is_latin);
/* The mode a field starts in when it gains focus (true: Latin). */
bool ttime_mode_lock_mode_on_focus(const ttime_mode_lock *m);

/* --- Shift tap: recognising a lone Shift press --- */

/* Platform-neutral timing. The shell decodes its OS events into presses and
 * releases of one side (0 left, 1 right) with a timestamp in seconds; it must
 * never swallow the modifier events themselves. A press held longer than
 * 0.35 s, or with Control/Option/Command (Ctrl/Alt/Win) down (`chord`), is not
 * a tap; two taps of one side within 0.5 s are a double. */
typedef struct ttime_shift_tap ttime_shift_tap;

ttime_shift_tap *ttime_shift_tap_new(void);
void ttime_shift_tap_free(ttime_shift_tap *t);
/* A non-modifier key (or another modifier) was pressed: a Shift held now is a
 * chord, and no first tap can pair with a later one. */
void ttime_shift_tap_key_down(ttime_shift_tap *t);
/* Forgets everything (activation/deactivation), so a lost release cannot stick. */
void ttime_shift_tap_reset(ttime_shift_tap *t);
/* `other_held`: the other Shift is already down (both together are a chord). */
void ttime_shift_tap_press(ttime_shift_tap *t, int side, double time, bool chord, bool other_held);
/* Returns 0 when this release is no tap, 1 a single tap, 2 the second of a
 * double. The first tap of a pair is reported at once as 1, so acting on 2 has
 * to undo what 1 did. */
int ttime_shift_tap_release(ttime_shift_tap *t, int side, double time, bool chord);
/* Whether that side is currently known to be down. */
bool ttime_shift_tap_held(const ttime_shift_tap *t, int side);

/* --- Stacker window state --- */

typedef struct ttime_stacker ttime_stacker;

ttime_stacker *ttime_stacker_new(bool precomposed);
void ttime_stacker_free(ttime_stacker *s);
/* Switches the output form and rebuilds the current stack. */
void ttime_stacker_set_precomposed(ttime_stacker *s, bool on);
/* Adds a consonant below the others. False (with a hint) for a letter that only
 * exists under another one when there is none above. */
bool ttime_stacker_add_layer(ttime_stacker *s, const char *key);
void ttime_stacker_remove_layer(ttime_stacker *s, int index);
/* Sets the vowel; setting the same vowel again goes back to the inherent a. */
void ttime_stacker_set_vowel(ttime_stacker *s, const char *vowel);
void ttime_stacker_toggle_mark(ttime_stacker *s, const char *mark);
/* Replaces the stack with keys separated by spaces ("k Sh"). */
void ttime_stacker_use_preset(ttime_stacker *s, const char *keys);
void ttime_stacker_clear(ttime_stacker *s);
void ttime_stacker_set_hint(ttime_stacker *s, const char *hint);
/* Typing narrows the letter grid; confirm adds the letter typed (an exact key,
 * else the only candidate). False, with a hint, when it names no letter. */
void ttime_stacker_type(ttime_stacker *s, const char *text);
bool ttime_stacker_confirm_typed(ttime_stacker *s);
/* Deletes the last typed character, else the last letter; false if nothing was left. */
bool ttime_stacker_backspace(ttime_stacker *s);
/* Returns the built text to insert ("" if the stack does not build) and starts
 * the next stack, with a hint showing the shortest EWTS for next time. */
char *ttime_stacker_consume(ttime_stacker *s);
/* Whether the grid shows `key` for what has been typed. */
bool ttime_stacker_matches(const ttime_stacker *s, const char *key);
/* The state to draw:
 *   {"layers":[...],"vowel":"","marks":[...],"typed":"","typedKey":"kh"|null,
 *    "hint":"","precomposed":false,"result":R}
 * where R is {"kind":"empty"}, {"kind":"failed","error":...} or
 *   {"kind":"built","text","canonical","shortest","codePoints","notes":[...]}.
 * The alphabet never changes: read it once with ttime_stack_alphabet_json(). */
char *ttime_stacker_state_json(const ttime_stacker *s);

/* --- Symbols window state --- */

typedef struct ttime_symbols_model ttime_symbols_model;

ttime_symbols_model *ttime_symbols_model_new(void);
void ttime_symbols_model_free(ttime_symbols_model *m);
/* Search text; any change resets the selection to the first result. */
void ttime_symbols_model_type(ttime_symbols_model *m, const char *text);
bool ttime_symbols_model_backspace(ttime_symbols_model *m);
void ttime_symbols_model_clear_query(ttime_symbols_model *m);
/* NULL or "" shows all categories. */
void ttime_symbols_model_set_category(ttime_symbols_model *m, const char *category);
/* The next category, wrapping through "all" (the Tab key). */
void ttime_symbols_model_next_category(ttime_symbols_model *m);
void ttime_symbols_model_move(ttime_symbols_model *m, int delta);
void ttime_symbols_model_select(ttime_symbols_model *m, int index);
void ttime_symbols_model_set_hint(ttime_symbols_model *m, const char *hint);
/* The state to draw:
 *   {"categories":[...],"query":"","category":"…"|null,"selected":n,"hint":"",
 *    "results":[{"id","category","text","ewts"(or null),"name","label","note",
 *                "codePoints","display"}]}
 * `display` is `text` with a dotted circle before a combining mark. */
char *ttime_symbols_model_state_json(const ttime_symbols_model *m);

/* --- Dictionary lookup (Christian Steinert's site; nothing is bundled) --- */

/* The term to look up: the selection if there is one (spaces and trailing
 * tsheg/shad trimmed), else the syllable just before the caret. Either may be
 * NULL; returns "" when there is nothing to look up. */
char *ttime_dictionary_term(const char *selection, const char *before);
/* The site's search page for `term`, or "" for a blank term. */
char *ttime_dictionary_url(const char *term);
/* The site's home page. */
char *ttime_dictionary_site(void);

void ttime_string_free(char *s);

#ifdef __cplusplus
}
#endif
#endif
