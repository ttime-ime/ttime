#include "Globals.h"

#include <msctf.h>
#include <objbase.h>
#include <string>

namespace {

// What T-Time is to TSF: a keyboard text service that provides display attributes
// (the underline), works in Store/immersive apps, and with the taskbar input indicator.
const GUID *const kCategories[] = {
    &GUID_TFCAT_TIP_KEYBOARD,
    &GUID_TFCAT_DISPLAYATTRIBUTEPROVIDER,
    &GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT,
    &GUID_TFCAT_TIPCAP_SYSTRAYSUPPORT,
};

HRESULT GetModuleFileNameWString(std::wstring *out) {
    wchar_t path[MAX_PATH] = {};
    DWORD n = GetModuleFileNameW(g_hInst, path, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return E_FAIL;
    *out = path;
    return S_OK;
}

HRESULT RecurseDeleteKey(HKEY hKeyParent, const wchar_t *subKey) {
    HKEY hKey = nullptr;
    LONG err = RegOpenKeyExW(hKeyParent, subKey, 0, KEY_READ | KEY_WRITE, &hKey);
    if (err != ERROR_SUCCESS) return HRESULT_FROM_WIN32(err);

    wchar_t child[256];
    DWORD childLen = 256;
    while (RegEnumKeyExW(hKey, 0, child, &childLen, nullptr, nullptr, nullptr, nullptr) ==
           ERROR_SUCCESS) {
        RecurseDeleteKey(hKey, child);
        childLen = 256;
    }
    RegCloseKey(hKey);
    err = RegDeleteKeyW(hKeyParent, subKey);
    return HRESULT_FROM_WIN32(err);
}

HRESULT RegisterClsid(const wchar_t *clsidStr, const wchar_t *dllPath) {
    std::wstring key = L"CLSID\\";
    key += clsidStr;

    HKEY hKey = nullptr;
    LONG err = RegCreateKeyExW(HKEY_CLASSES_ROOT, key.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr,
                               &hKey, nullptr);
    if (err != ERROR_SUCCESS) return HRESULT_FROM_WIN32(err);

    RegSetValueExW(hKey, nullptr, 0, REG_SZ, (const BYTE *)TTIME_TEXT_SERVICE_DESC,
                   (DWORD)((wcslen(TTIME_TEXT_SERVICE_DESC) + 1) * sizeof(wchar_t)));
    RegCloseKey(hKey);

    std::wstring inproc = key + L"\\InProcServer32";
    err = RegCreateKeyExW(HKEY_CLASSES_ROOT, inproc.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &hKey,
                          nullptr);
    if (err != ERROR_SUCCESS) return HRESULT_FROM_WIN32(err);

    RegSetValueExW(hKey, nullptr, 0, REG_SZ, (const BYTE *)dllPath,
                   (DWORD)((dllPath ? wcslen(dllPath) : 0) + 1) * sizeof(wchar_t));
    const wchar_t *model = L"Apartment";
    RegSetValueExW(hKey, L"ThreadingModel", 0, REG_SZ, (const BYTE *)model,
                   (DWORD)((wcslen(model) + 1) * sizeof(wchar_t)));
    RegCloseKey(hKey);
    return S_OK;
}

HRESULT UnregisterClsid(const wchar_t *clsidStr) {
    std::wstring key = L"CLSID\\";
    key += clsidStr;
    RecurseDeleteKey(HKEY_CLASSES_ROOT, key.c_str());
    return S_OK;
}

HRESULT GuidToString(REFGUID guid, wchar_t *buf, size_t cch) {
    if (StringFromGUID2(guid, buf, (int)cch) == 0) return E_FAIL;
    return S_OK;
}

} // namespace

HRESULT RegisterServer() {
    wchar_t clsidStr[64] = {};
    HRESULT hr = GuidToString(CLSID_TTimeTextService, clsidStr, 64);
    if (FAILED(hr)) return hr;

    std::wstring dllPath;
    hr = GetModuleFileNameWString(&dllPath);
    if (FAILED(hr)) return hr;

    hr = RegisterClsid(clsidStr, dllPath.c_str());
    if (FAILED(hr)) return hr;

    ITfInputProcessorProfiles *profiles = nullptr;
    hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                          IID_ITfInputProcessorProfiles, (void **)&profiles);
    if (FAILED(hr)) return hr;

    hr = profiles->Register(CLSID_TTimeTextService);
    if (SUCCEEDED(hr)) {
        // No icon file yet: Windows shows the name instead. The profile is not enabled
        // here; the person adds T-Time as a keyboard in Settings.
        hr = profiles->AddLanguageProfile(
            CLSID_TTimeTextService, TTIME_LANGID, GUID_TTimeProfile, TTIME_TEXT_SERVICE_DESC,
            static_cast<ULONG>(wcslen(TTIME_TEXT_SERVICE_DESC)), nullptr, 0, 0);
    }
    profiles->Release();
    if (FAILED(hr)) return hr;

    ITfCategoryMgr *catMgr = nullptr;
    hr = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER, IID_ITfCategoryMgr,
                          (void **)&catMgr);
    if (FAILED(hr)) return hr;
    for (const GUID *cat : kCategories) {
        hr = catMgr->RegisterCategory(CLSID_TTimeTextService, *cat, CLSID_TTimeTextService);
        if (FAILED(hr)) break;
    }
    catMgr->Release();
    return hr;
}

HRESULT UnregisterServer() {
    ITfInputProcessorProfiles *profiles = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                                   IID_ITfInputProcessorProfiles, (void **)&profiles))) {
        profiles->Unregister(CLSID_TTimeTextService);
        profiles->Release();
    }

    ITfCategoryMgr *catMgr = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
                                   IID_ITfCategoryMgr, (void **)&catMgr))) {
        for (const GUID *cat : kCategories) {
            catMgr->UnregisterCategory(CLSID_TTimeTextService, *cat, CLSID_TTimeTextService);
        }
        catMgr->Release();
    }

    wchar_t clsidStr[64] = {};
    if (SUCCEEDED(GuidToString(CLSID_TTimeTextService, clsidStr, 64))) {
        UnregisterClsid(clsidStr);
    }
    return S_OK;
}
