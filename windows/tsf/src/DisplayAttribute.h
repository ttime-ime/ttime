#pragma once

#include <msctf.h>

// The look of T-Time's provisional text: a solid underline in the text colour, the
// usual input style. Applications draw it when the composition range carries
// GUID_PROP_ATTRIBUTE with the atom of GUID_TTimeDisplayAttribute.
class DisplayAttributeInfo : public ITfDisplayAttributeInfo {
public:
    DisplayAttributeInfo();
    ~DisplayAttributeInfo();

    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

    STDMETHODIMP GetGUID(GUID *pguid) override;
    STDMETHODIMP GetDescription(BSTR *pbstrDesc) override;
    STDMETHODIMP GetAttributeInfo(TF_DISPLAYATTRIBUTE *pda) override;
    STDMETHODIMP SetAttributeInfo(const TF_DISPLAYATTRIBUTE *pda) override;
    STDMETHODIMP Reset() override;

    static const TF_DISPLAYATTRIBUTE kInput;

private:
    LONG ref_ = 1;
};

// Enumerates the one display attribute T-Time provides.
class DisplayAttributeEnum : public IEnumTfDisplayAttributeInfo {
public:
    DisplayAttributeEnum();
    ~DisplayAttributeEnum();

    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

    STDMETHODIMP Clone(IEnumTfDisplayAttributeInfo **ppEnum) override;
    STDMETHODIMP Next(ULONG ulCount, ITfDisplayAttributeInfo **rgInfo, ULONG *pcFetched) override;
    STDMETHODIMP Reset() override;
    STDMETHODIMP Skip(ULONG ulCount) override;

private:
    LONG ref_ = 1;
    ULONG index_ = 0;
};
