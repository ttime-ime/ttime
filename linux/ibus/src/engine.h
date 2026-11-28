#ifndef TTIME_IBUS_ENGINE_H
#define TTIME_IBUS_ENGINE_H

#include <ibus.h>

#define TTIME_TYPE_ENGINE (ttime_engine_get_type())
#define TTIME_ENGINE(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), TTIME_TYPE_ENGINE, TTimeEngine))

typedef struct _TTimeEngine TTimeEngine;
typedef struct _TTimeEngineClass TTimeEngineClass;

GType ttime_engine_get_type(void);

#endif
