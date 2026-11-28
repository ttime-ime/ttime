#pragma once

#include <windows.h>
#include <unknwn.h>  // IClassFactory (WIN32_LEAN_AND_MEAN leaves out the COM headers)

HRESULT CreateClassFactory(IClassFactory **ppFactory);
