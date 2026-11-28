#include "DisplayAttribute.h"

#include "Globals.h"

#include <new>

const TF_DISPLAYATTRIBUTE DisplayAttributeInfo::kInput = {
    {TF_CT_NONE, 0},  // text colour: the application's
    {TF_CT_NONE, 0},  // background: the application's
    TF_LS_SOLID,        // underline style
    FALSE,              // thin line
    {TF_CT_NONE, 0},  // underline colour: the text colour
    TF_ATTR_INPUT,      // provisional input
};

DisplayAttributeInfo::DisplayAttributeInfo() { DllAddRef(); }
DisplayAttributeInfo::~DisplayAttributeInfo() { DllRelease(); }

STDMETHODIMP DisplayAttributeInfo::QueryInterface(REFIID riid, void **ppvObj) {
    if (!ppvObj) return E_INVALIDARG;
    *ppvObj = nullptr;
    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfDisplayAttributeInfo)) {
        *ppvObj = static_cast<ITfDisplayAttributeInfo *>(this);
    } else {
        return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) DisplayAttributeInfo::AddRef() { return InterlockedIncrement(&ref_); }

STDMETHODIMP_(ULONG) DisplayAttributeInfo::Release() {
    LONG c = InterlockedDecrement(&ref_);
    if (c == 0) delete this;
    return c;
}

STDMETHODIMP DisplayAttributeInfo::GetGUID(GUID *pguid) {
    if (!pguid) return E_INVALIDARG;
    *pguid = GUID_TTimeDisplayAttribute;
    return S_OK;
}

STDMETHODIMP DisplayAttributeInfo::GetDescription(BSTR *pbstrDesc) {
    if (!pbstrDesc) return E_INVALIDARG;
    *pbstrDesc = SysAllocString(L"T-Time input");
    return *pbstrDesc ? S_OK : E_OUTOFMEMORY;
}

STDMETHODIMP DisplayAttributeInfo::GetAttributeInfo(TF_DISPLAYATTRIBUTE *pda) {
    if (!pda) return E_INVALIDARG;
    *pda = kInput;
    return S_OK;
}

STDMETHODIMP DisplayAttributeInfo::SetAttributeInfo(const TF_DISPLAYATTRIBUTE * /*pda*/) {
    return E_NOTIMPL;  // the style is fixed
}

STDMETHODIMP DisplayAttributeInfo::Reset() { return S_OK; }

DisplayAttributeEnum::DisplayAttributeEnum() { DllAddRef(); }
DisplayAttributeEnum::~DisplayAttributeEnum() { DllRelease(); }

STDMETHODIMP DisplayAttributeEnum::QueryInterface(REFIID riid, void **ppvObj) {
    if (!ppvObj) return E_INVALIDARG;
    *ppvObj = nullptr;
    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IEnumTfDisplayAttributeInfo)) {
        *ppvObj = static_cast<IEnumTfDisplayAttributeInfo *>(this);
    } else {
        return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) DisplayAttributeEnum::AddRef() { return InterlockedIncrement(&ref_); }

STDMETHODIMP_(ULONG) DisplayAttributeEnum::Release() {
    LONG c = InterlockedDecrement(&ref_);
    if (c == 0) delete this;
    return c;
}

STDMETHODIMP DisplayAttributeEnum::Clone(IEnumTfDisplayAttributeInfo **ppEnum) {
    if (!ppEnum) return E_INVALIDARG;
    auto *clone = new (std::nothrow) DisplayAttributeEnum();
    if (!clone) return E_OUTOFMEMORY;
    clone->index_ = index_;
    *ppEnum = clone;
    return S_OK;
}

STDMETHODIMP DisplayAttributeEnum::Next(ULONG ulCount, ITfDisplayAttributeInfo **rgInfo,
                                            ULONG *pcFetched) {
    ULONG fetched = 0;
    if (ulCount > 0 && !rgInfo) return E_INVALIDARG;
    if (ulCount > 0 && index_ == 0) {
        auto *info = new (std::nothrow) DisplayAttributeInfo();
        if (!info) return E_OUTOFMEMORY;
        rgInfo[0] = info;
        fetched = 1;
        index_ = 1;
    }
    if (pcFetched) *pcFetched = fetched;
    return fetched == ulCount ? S_OK : S_FALSE;
}

STDMETHODIMP DisplayAttributeEnum::Reset() {
    index_ = 0;
    return S_OK;
}

STDMETHODIMP DisplayAttributeEnum::Skip(ULONG ulCount) {
    if (ulCount > 0 && index_ == 0) {
        index_ = 1;
        return ulCount == 1 ? S_OK : S_FALSE;
    }
    return ulCount == 0 ? S_OK : S_FALSE;
}
