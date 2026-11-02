/* C interface to the T-Time engine. Strings are UTF-8 and NUL-terminated.
 * Every `char *` returned by this library is owned by the caller and must be
 * released with ttime_string_free(). A NULL session or NULL text argument is
 * treated as empty and never crashes. */
#ifndef TTIME_H
#define TTIME_H

#include <stdbool.h>

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

void ttime_string_free(char *s);

#ifdef __cplusplus
}
#endif
#endif
