#pragma once

#include <windows.h>
#include <msctf.h>
#include <atomic>
#include <string>

#include "Guids.h"

#define TTIME_TEXT_SERVICE_DESC L"T-Time"
#define TTIME_LANGID MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US)

extern HINSTANCE g_hInst;
extern std::atomic<LONG> g_dllRefCount;

void DllAddRef();
void DllRelease();

HRESULT RegisterServer();
HRESULT UnregisterServer();

// UTF-8 from the engine to the UTF-16 TSF wants; "" for NULL or invalid input.
std::wstring Utf8ToWide(const char *utf8);
