#pragma once

#include <windows.h>
#include <guiddef.h>

// T-Time Text Service CLSID (stable; do not change once published).
// {B7E4C2A1-9F3D-4E8B-A1C6-2D5E8F0A1B3C}
EXTERN_C const GUID CLSID_TTimeTextService;

// Language profile under en-US (EWTS is typed on a Latin keyboard).
// {C8F5D3B2-0A4E-5F9C-B2D7-3E6F9A1B2C4D}
EXTERN_C const GUID GUID_TTimeProfile;

EXTERN_C const GUID GUID_TTimeDisplayAttribute;
