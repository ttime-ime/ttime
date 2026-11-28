#include "engine.h"

#include <stdlib.h>
#include <string.h>

static IBusBus *bus = NULL;
static IBusFactory *factory = NULL;

/* Executed as a component: ibus-daemon starts us with --ibus. */
static void ibus_disconnected_cb(IBusBus *b, gpointer user_data) {
    (void)b;
    (void)user_data;
    ibus_quit();
}

static void start_component(void) {
    ibus_init();
    bus = ibus_bus_new();
    g_object_ref_sink(bus);

    if (!ibus_bus_is_connected(bus)) {
        g_warning("T-Time: not connected to IBus daemon");
        exit(1);
    }

    g_signal_connect(bus, "disconnected", G_CALLBACK(ibus_disconnected_cb), NULL);

    factory = ibus_factory_new(ibus_bus_get_connection(bus));
    g_object_ref_sink(factory);
    ibus_factory_add_engine(factory, "ttime", TTIME_TYPE_ENGINE);

    /* flags 0: normal name request; return 0 means failure. */
    if (ibus_bus_request_name(bus, "org.freedesktop.IBus.TTime", 0) == 0) {
        g_warning("T-Time: could not request IBus bus name");
        exit(1);
    }

    ibus_main();
}

int main(int argc, char **argv) {
    gboolean ibus = FALSE;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--ibus") == 0) ibus = TRUE;
    }

    if (ibus) {
        start_component();
        return 0;
    }

    /* Without --ibus, print a short usage hint (useful when someone runs the
     * binary by hand). IBus itself always passes --ibus. */
    g_print("ibus-engine-ttime: run under IBus (component exec uses --ibus).\n");
    g_print("See linux/README.md for install steps.\n");
    return 0;
}
