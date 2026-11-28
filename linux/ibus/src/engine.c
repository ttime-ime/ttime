#include "engine.h"

#include "composer_host.h"

#include <string.h>

struct _TTimeEngine {
    IBusEngine parent;
    ComposerHost host;
    gboolean composing;
};

struct _TTimeEngineClass {
    IBusEngineClass parent;
};

G_DEFINE_TYPE(TTimeEngine, ttime_engine, IBUS_TYPE_ENGINE)

static void commit_utf8(IBusEngine *engine, const char *utf8) {
    if (!utf8 || !utf8[0]) return;
    IBusText *text = ibus_text_new_from_string(utf8);
    ibus_engine_commit_text(engine, text);
}

static void clear_preedit(IBusEngine *engine, TTimeEngine *self) {
    IBusText *empty = ibus_text_new_from_string("");
    ibus_engine_update_preedit_text(engine, empty, 0, FALSE);
    self->composing = FALSE;
}

static void set_preedit(IBusEngine *engine, TTimeEngine *self, const char *utf8) {
    if (!utf8 || !utf8[0]) {
        clear_preedit(engine, self);
        return;
    }
    IBusText *text = ibus_text_new_from_string(utf8);
    const guint len = g_utf8_strlen(utf8, -1);
    /* Underline the whole provisional run (IBusAttrList type underline). */
    ibus_text_append_attribute(text, IBUS_ATTR_TYPE_UNDERLINE, IBUS_ATTR_UNDERLINE_SINGLE, 0, len);
    ibus_engine_update_preedit_text(engine, text, len, TRUE);
    self->composing = TRUE;
}

static void apply_outcome(IBusEngine *engine, TTimeEngine *self, const ttime_outcome *out) {
    if (!out) return;

    /* Same order as macOS: commit insert first, then set/clear marked preedit. */
    if (out->insert && out->insert[0]) {
        clear_preedit(engine, self);
        commit_utf8(engine, out->insert);
    }

    if (out->marked && out->marked[0]) {
        set_preedit(engine, self, out->marked);
    } else if (out->handled || (out->insert && out->insert[0])) {
        /* Empty marked after a handled key or a commit clears the preedit. */
        if (self->composing) clear_preedit(engine, self);
    }
}

static void commit_pending(IBusEngine *engine, TTimeEngine *self) {
    char *pending = composer_host_commit_all(&self->host);
    clear_preedit(engine, self);
    if (pending) {
        commit_utf8(engine, pending);
        ttime_string_free(pending);
    }
}

static gboolean ttime_engine_process_key_event(IBusEngine *engine, guint keyval, guint keycode,
                                               guint modifiers) {
    TTimeEngine *self = TTIME_ENGINE(engine);
    (void)keycode;

    const bool is_release = (modifiers & IBUS_RELEASE_MASK) != 0;
    const bool is_key_down = !is_release;
    /* IBus sets IBUS_MODIFIER_MASK bits; auto-repeat is not always flagged.
     * Use IBUS_IGNORED_MASK historically; modern IBus may not set a repeat bit.
     * Pass false unless we detect lock+repeat patterns — long-press accents are
     * out of scope for this MVP. */
    const bool is_repeat = FALSE;

    ttime_outcome out = {0};
    const bool handled =
        composer_host_handle_key(&self->host, keyval, modifiers, is_key_down, is_repeat, &out);

    const bool has_insert = out.insert && out.insert[0];
    const bool has_marked = out.marked && out.marked[0];
    if (handled || has_insert || has_marked || (out.handled && self->composing)) {
        apply_outcome(engine, self, &out);
    }
    ttime_outcome_free(&out);

    /* Never swallow Shift: the application must see the modifier. */
    if (keyval == IBUS_Shift_L || keyval == IBUS_Shift_R) return FALSE;

    return handled ? TRUE : FALSE;
}

static void ttime_engine_focus_in(IBusEngine *engine) {
    TTimeEngine *self = TTIME_ENGINE(engine);
    composer_host_on_activate(&self->host);
    self->composing = FALSE;
    IBUS_ENGINE_CLASS(ttime_engine_parent_class)->focus_in(engine);
}

static void ttime_engine_focus_out(IBusEngine *engine) {
    TTimeEngine *self = TTIME_ENGINE(engine);
    commit_pending(engine, self);
    IBUS_ENGINE_CLASS(ttime_engine_parent_class)->focus_out(engine);
}

static void ttime_engine_reset(IBusEngine *engine) {
    TTimeEngine *self = TTIME_ENGINE(engine);
    commit_pending(engine, self);
    composer_host_reset(&self->host);
    IBUS_ENGINE_CLASS(ttime_engine_parent_class)->reset(engine);
}

static void ttime_engine_disable(IBusEngine *engine) {
    TTimeEngine *self = TTIME_ENGINE(engine);
    commit_pending(engine, self);
    IBUS_ENGINE_CLASS(ttime_engine_parent_class)->disable(engine);
}

static void ttime_engine_init(TTimeEngine *self) {
    composer_host_init(&self->host);
    self->composing = FALSE;
}

static void ttime_engine_finalize(GObject *object) {
    TTimeEngine *self = TTIME_ENGINE(object);
    composer_host_destroy(&self->host);
    G_OBJECT_CLASS(ttime_engine_parent_class)->finalize(object);
}

static void ttime_engine_class_init(TTimeEngineClass *klass) {
    GObjectClass *object_class = G_OBJECT_CLASS(klass);
    IBusEngineClass *engine_class = IBUS_ENGINE_CLASS(klass);

    object_class->finalize = ttime_engine_finalize;
    engine_class->process_key_event = ttime_engine_process_key_event;
    engine_class->focus_in = ttime_engine_focus_in;
    engine_class->focus_out = ttime_engine_focus_out;
    engine_class->reset = ttime_engine_reset;
    engine_class->disable = ttime_engine_disable;
}
