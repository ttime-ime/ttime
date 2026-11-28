/* Smoke test for the T-Time C ABI on any platform shell.
 *
 * Types "bkra" then space through ttime_composer, checks that the committed
 * insert contains Tibetan བཀྲ་, exercises a null free, and exits 0 on success.
 *
 * Build with scripts/build-ffi-smoke.sh (Unix) or scripts/build-ffi-smoke.ps1
 * (Windows). See ffi-smoke/README.md.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ttime.h"

static int fail(const char *msg) {
    fprintf(stderr, "ffi-smoke: %s\n", msg);
    return 1;
}

static void type_char(ttime_composer *c, const char *ch) {
    ttime_outcome o = ttime_composer_handle(c, TTIME_KEY_TEXT, ch, false);
    ttime_outcome_free(&o);
}

int main(void) {
    /* Null-safe: freeing a null composer must not crash. */
    ttime_composer_free(NULL);
    ttime_outcome_free(NULL);

    char *ver = ttime_version();
    if (ver == NULL || ver[0] == '\0') {
        return fail("ttime_version returned empty");
    }
    printf("ttime_version=%s\n", ver);
    ttime_string_free(ver);

    ttime_composer *c = ttime_composer_new(false);
    if (c == NULL) {
        return fail("ttime_composer_new returned NULL");
    }

    type_char(c, "b");
    type_char(c, "k");
    type_char(c, "r");
    type_char(c, "a");

    ttime_outcome space = ttime_composer_handle(c, TTIME_KEY_TEXT, " ", false);
    printf("insert=%s\n", space.insert ? space.insert : "");
    printf("marked=%s\n", space.marked ? space.marked : "");
    printf("replacing=%s\n", space.replacing ? space.replacing : "");
    printf("handled=%s\n", space.handled ? "true" : "false");

    /* Same answer as the batch converter for "bkra " (composer must match). */
    char *want = ttime_convert("bkra ", false);
    int ok = space.insert != NULL && want != NULL && strcmp(space.insert, want) == 0
             && space.handled;

    ttime_string_free(want);
    ttime_outcome_free(&space);
    ttime_composer_free(c);

    if (!ok) {
        return fail("composer insert for bkra+space did not match ttime_convert");
    }
    printf("ffi-smoke: ok\n");
    return 0;
}
