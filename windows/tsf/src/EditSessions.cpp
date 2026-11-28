#include "EditSessions.h"

#include "Globals.h"
#include "TextService.h"

EditSessionBase::EditSessionBase(TextService *service, ITfContext *context)
    : service_(service), context_(context) {
    service_->AddRef();
    if (context_) context_->AddRef();
    DllAddRef();
}

EditSessionBase::~EditSessionBase() {
    if (context_) context_->Release();
    service_->Release();
    DllRelease();
}

STDMETHODIMP EditSessionBase::QueryInterface(REFIID riid, void **ppvObj) {
    if (!ppvObj) return E_INVALIDARG;
    *ppvObj = nullptr;
    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfEditSession)) {
        *ppvObj = static_cast<ITfEditSession *>(this);
    } else {
        return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) EditSessionBase::AddRef() { return InterlockedIncrement(&ref_); }

STDMETHODIMP_(ULONG) EditSessionBase::Release() {
    LONG c = InterlockedDecrement(&ref_);
    if (c == 0) delete this;
    return c;
}

CommitEditSession::CommitEditSession(TextService *service, ITfContext *context, std::wstring text,
                                     std::wstring replacing, ITfComposition *composition)
    : EditSessionBase(service, context),
      text_(std::move(text)),
      replacing_(std::move(replacing)),
      composition_(composition) {}

CommitEditSession::~CommitEditSession() {
    if (composition_) composition_->Release();
}

STDMETHODIMP CommitEditSession::DoEditSession(TfEditCookie ec) {
    ITfComposition *comp = composition_;
    composition_ = nullptr;
    return service_->CommitAt(ec, context_, text_, replacing_, comp);
}

SetCompositionEditSession::SetCompositionEditSession(TextService *service, ITfContext *context,
                                                     std::wstring text)
    : EditSessionBase(service, context), text_(std::move(text)) {}

STDMETHODIMP SetCompositionEditSession::DoEditSession(TfEditCookie ec) {
    return service_->SetCompositionAt(ec, context_, text_);
}

CancelCompositionEditSession::CancelCompositionEditSession(TextService *service, ITfContext *context)
    : EditSessionBase(service, context) {}

STDMETHODIMP CancelCompositionEditSession::DoEditSession(TfEditCookie ec) {
    service_->CancelCompositionAt(ec);
    return S_OK;
}
