#include "Globals.h"

HINSTANCE g_hInst = nullptr;
std::atomic<LONG> g_dllRefCount{0};

void DllAddRef() { g_dllRefCount.fetch_add(1); }
void DllRelease() { g_dllRefCount.fetch_sub(1); }

std::wstring Utf8ToWide(const char *utf8) {
    if (!utf8 || !*utf8) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, nullptr, 0);
    if (n <= 1) return {};
    std::wstring out(static_cast<size_t>(n - 1), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, out.data(), n);
    return out;
}
