#include "Globals.h"
#include "TextService.h"

#include <new>

class ClassFactory : public IClassFactory {
public:
    ClassFactory() { DllAddRef(); }
    ~ClassFactory() { DllRelease(); }

    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj) override {
        if (!ppvObj) return E_INVALIDARG;
        *ppvObj = nullptr;
        if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IClassFactory)) {
            *ppvObj = static_cast<IClassFactory *>(this);
        } else {
            return E_NOINTERFACE;
        }
        AddRef();
        return S_OK;
    }

    STDMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&ref_); }
    STDMETHODIMP_(ULONG) Release() override {
        LONG c = InterlockedDecrement(&ref_);
        if (c == 0) delete this;
        return c;
    }

    STDMETHODIMP CreateInstance(IUnknown *pUnkOuter, REFIID riid, void **ppvObj) override {
        if (ppvObj) *ppvObj = nullptr;
        if (pUnkOuter) return CLASS_E_NOAGGREGATION;
        IUnknown *unk = nullptr;
        HRESULT hr = CreateTextService(&unk);
        if (FAILED(hr)) return hr;
        hr = unk->QueryInterface(riid, ppvObj);
        unk->Release();
        return hr;
    }

    STDMETHODIMP LockServer(BOOL fLock) override {
        if (fLock)
            DllAddRef();
        else
            DllRelease();
        return S_OK;
    }

private:
    LONG ref_ = 1;
};

HRESULT CreateClassFactory(IClassFactory **ppFactory) {
    if (!ppFactory) return E_INVALIDARG;
    *ppFactory = new (std::nothrow) ClassFactory();
    return *ppFactory ? S_OK : E_OUTOFMEMORY;
}
