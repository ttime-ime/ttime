#include "ClassFactory.h"
#include "Globals.h"

#include <new>
#include <objbase.h>

BOOL APIENTRY DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID /*lpReserved*/) {
    switch (dwReason) {
    case DLL_PROCESS_ATTACH:
        g_hInst = hInstance;
        DisableThreadLibraryCalls(hInstance);
        break;
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

STDAPI DllCanUnloadNow() {
    return g_dllRefCount.load() == 0 ? S_OK : S_FALSE;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, void **ppvObj) {
    if (ppvObj) *ppvObj = nullptr;
    if (!IsEqualCLSID(rclsid, CLSID_TTimeTextService)) return CLASS_E_CLASSNOTAVAILABLE;

    IClassFactory *factory = nullptr;
    HRESULT hr = CreateClassFactory(&factory);
    if (FAILED(hr)) return hr;
    hr = factory->QueryInterface(riid, ppvObj);
    factory->Release();
    return hr;
}

STDAPI DllRegisterServer() {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool needUninit = SUCCEEDED(hr);
    if (hr == S_FALSE) {
        needUninit = true;
        hr = S_OK;
    }
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return hr;

    hr = RegisterServer();
    if (needUninit) CoUninitialize();
    return hr;
}

STDAPI DllUnregisterServer() {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool needUninit = SUCCEEDED(hr);
    if (hr == S_FALSE) {
        needUninit = true;
        hr = S_OK;
    }
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return hr;

    hr = UnregisterServer();
    if (needUninit) CoUninitialize();
    return hr;
}
