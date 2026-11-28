#include "TextService.h"

#include "DisplayAttribute.h"
#include "EditSessions.h"
#include "Globals.h"
#include "Guids.h"

#include <new>
#include <string>

namespace {

// Sessions run synchronously when TSF allows it and are queued otherwise (inside
// focus notifications, for example), in request order per context.
constexpr DWORD kSessionFlags = TF_ES_ASYNCDONTCARE | TF_ES_READWRITE;

HRESULT Request(TfClientId client, ITfContext *pic, ITfEditSession *session) {
    if (!pic || !session) return E_INVALIDARG;
    HRESULT hrSession = S_OK;
    HRESULT hr = pic->RequestEditSession(client, session, kSessionFlags, &hrSession);
    session->Release();
    return FAILED(hr) ? hr : hrSession;
}

bool IsShift(WPARAM vk) { return vk == VK_SHIFT || vk == VK_LSHIFT || vk == VK_RSHIFT; }

}  // namespace

TextService::TextService() { DllAddRef(); }

TextService::~TextService() {
    if (composition_) composition_->Release();
    DllRelease();
}

STDMETHODIMP TextService::QueryInterface(REFIID riid, void **ppvObj) {
    if (!ppvObj) return E_INVALIDARG;
    *ppvObj = nullptr;

    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfTextInputProcessor) ||
        IsEqualIID(riid, IID_ITfTextInputProcessorEx)) {
        *ppvObj = static_cast<ITfTextInputProcessorEx *>(this);
    } else if (IsEqualIID(riid, IID_ITfKeyEventSink)) {
        *ppvObj = static_cast<ITfKeyEventSink *>(this);
    } else if (IsEqualIID(riid, IID_ITfThreadMgrEventSink)) {
        *ppvObj = static_cast<ITfThreadMgrEventSink *>(this);
    } else if (IsEqualIID(riid, IID_ITfCompositionSink)) {
        *ppvObj = static_cast<ITfCompositionSink *>(this);
    } else if (IsEqualIID(riid, IID_ITfDisplayAttributeProvider)) {
        *ppvObj = static_cast<ITfDisplayAttributeProvider *>(this);
    } else {
        return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) TextService::AddRef() { return InterlockedIncrement(&ref_); }

STDMETHODIMP_(ULONG) TextService::Release() {
    LONG c = InterlockedDecrement(&ref_);
    if (c == 0) delete this;
    return c;
}

// --- Activation ---------------------------------------------------------------

STDMETHODIMP TextService::Activate(ITfThreadMgr *pThreadMgr, TfClientId tfClientId) {
    return ActivateEx(pThreadMgr, tfClientId, 0);
}

STDMETHODIMP TextService::ActivateEx(ITfThreadMgr *pThreadMgr, TfClientId tfClientId,
                                     DWORD /*dwFlags*/) {
    if (!pThreadMgr) return E_INVALIDARG;
    threadMgr_ = pThreadMgr;
    threadMgr_->AddRef();
    clientId_ = tfClientId;

    if (!InitThreadMgrEventSink() || !InitKeyEventSink()) {
        Deactivate();
        return E_FAIL;
    }
    InitDisplayAttributeAtom();
    host_.OnActivate();
    return S_OK;
}

STDMETHODIMP TextService::Deactivate() {
    if (threadMgr_) {
        ITfDocumentMgr *doc = nullptr;
        if (SUCCEEDED(threadMgr_->GetFocus(&doc)) && doc) {
            ITfContext *ctx = nullptr;
            if (SUCCEEDED(doc->GetTop(&ctx)) && ctx) {
                CommitPendingInto(ctx);
                ctx->Release();
            }
            doc->Release();
        }
    }
    if (composition_) {  // no document to finish it in
        composition_->Release();
        composition_ = nullptr;
    }
    host_.Reset();

    UninitKeyEventSink();
    UninitThreadMgrEventSink();
    if (threadMgr_) {
        threadMgr_->Release();
        threadMgr_ = nullptr;
    }
    clientId_ = TF_CLIENTID_NULL;
    lastTest_ = {};
    return S_OK;
}

bool TextService::InitKeyEventSink() {
    ITfKeystrokeMgr *ksm = nullptr;
    if (FAILED(threadMgr_->QueryInterface(IID_ITfKeystrokeMgr, (void **)&ksm))) return false;
    HRESULT hr = ksm->AdviseKeyEventSink(clientId_, static_cast<ITfKeyEventSink *>(this), TRUE);
    ksm->Release();
    return SUCCEEDED(hr);
}

void TextService::UninitKeyEventSink() {
    if (!threadMgr_) return;
    ITfKeystrokeMgr *ksm = nullptr;
    if (SUCCEEDED(threadMgr_->QueryInterface(IID_ITfKeystrokeMgr, (void **)&ksm))) {
        ksm->UnadviseKeyEventSink(clientId_);
        ksm->Release();
    }
}

bool TextService::InitThreadMgrEventSink() {
    ITfSource *source = nullptr;
    if (FAILED(threadMgr_->QueryInterface(IID_ITfSource, (void **)&source))) return false;
    HRESULT hr = source->AdviseSink(IID_ITfThreadMgrEventSink,
                                    static_cast<ITfThreadMgrEventSink *>(this), &threadMgrCookie_);
    source->Release();
    return SUCCEEDED(hr);
}

void TextService::UninitThreadMgrEventSink() {
    if (!threadMgr_ || threadMgrCookie_ == TF_INVALID_COOKIE) return;
    ITfSource *source = nullptr;
    if (SUCCEEDED(threadMgr_->QueryInterface(IID_ITfSource, (void **)&source))) {
        source->UnadviseSink(threadMgrCookie_);
        source->Release();
    }
    threadMgrCookie_ = TF_INVALID_COOKIE;
}

void TextService::InitDisplayAttributeAtom() {
    ITfCategoryMgr *catMgr = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER,
                                   IID_ITfCategoryMgr, (void **)&catMgr))) {
        if (FAILED(catMgr->RegisterGUID(GUID_TTimeDisplayAttribute, &displayAtom_))) {
            displayAtom_ = TF_INVALID_GUIDATOM;
        }
        catMgr->Release();
    }
}

// --- Keys ---------------------------------------------------------------------

STDMETHODIMP TextService::OnSetFocus(BOOL /*fForeground*/) { return S_OK; }

STDMETHODIMP TextService::OnTestKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam,
                                        BOOL *pfEaten) {
    return HandleKey(pic, wParam, lParam, TRUE, pfEaten, true);
}

STDMETHODIMP TextService::OnTestKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) {
    return HandleKey(pic, wParam, lParam, FALSE, pfEaten, true);
}

STDMETHODIMP TextService::OnKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) {
    return HandleKey(pic, wParam, lParam, TRUE, pfEaten, false);
}

STDMETHODIMP TextService::OnKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) {
    return HandleKey(pic, wParam, lParam, FALSE, pfEaten, false);
}

STDMETHODIMP TextService::OnPreservedKey(ITfContext * /*pic*/, REFGUID /*rguid*/, BOOL *pfEaten) {
    if (pfEaten) *pfEaten = FALSE;
    return S_OK;
}

HRESULT TextService::HandleKey(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL isDown,
                               BOOL *pfEaten, bool fromTest) {
    if (!pfEaten) return E_INVALIDARG;
    *pfEaten = FALSE;
    if (!pic) return S_OK;

    // The OnKey* that follows an OnTestKey* for the same event: already processed.
    if (!fromTest && lastTest_.valid && lastTest_.wParam == wParam && lastTest_.lParam == lParam &&
        lastTest_.down == isDown) {
        lastTest_.valid = false;
        *pfEaten = lastTest_.eaten;
        return S_OK;
    }

    ttime_outcome outcome = {};
    const bool eaten = host_.HandleKey(wParam, lParam, isDown != FALSE, &outcome);
    // Shift is never eaten, so the application always sees it; a tap's mode switch
    // still applies through the outcome.
    *pfEaten = (eaten && !IsShift(wParam)) ? TRUE : FALSE;
    if (fromTest) lastTest_ = {true, wParam, lParam, isDown, *pfEaten};

    HRESULT hr = ApplyOutcome(pic, outcome);
    ttime_outcome_free(&outcome);
    return hr;
}

// Applies insert/marked even when the key is not eaten: Return commits the pending
// syllable and then the application gets the key, as on macOS.
HRESULT TextService::ApplyOutcome(ITfContext *pic, const ttime_outcome &outcome) {
    const std::wstring insert = Utf8ToWide(outcome.insert);
    const std::wstring marked = Utf8ToWide(outcome.marked);
    const std::wstring replacing = Utf8ToWide(outcome.replacing);

    HRESULT hr = S_OK;
    if (!insert.empty() || !replacing.empty()) {
        hr = RequestCommit(pic, insert, replacing, nullptr);
    }
    if (!marked.empty()) {
        HRESULT hr2 = RequestSetComposition(pic, marked);
        if (SUCCEEDED(hr)) hr = hr2;
    } else if (insert.empty() && outcome.handled && IsComposing()) {
        // The run was emptied (Backspace) or cancelled (Escape).
        hr = RequestCancelComposition(pic);
    }
    return hr;
}

void TextService::CommitPendingInto(ITfContext *pic) {
    char *pending = host_.CommitAll();
    std::wstring text = Utf8ToWide(pending);
    ttime_string_free(pending);
    // Hand the open composition to the session, so it is finished in this document
    // even if the session runs after focus has moved on.
    ITfComposition *comp = composition_;
    composition_ = nullptr;
    if (text.empty() && !comp) return;
    if (pic) {
        RequestCommit(pic, std::move(text), L"", comp);
    } else if (comp) {
        comp->Release();
    }
}

// --- Edit sessions ------------------------------------------------------------

HRESULT TextService::RequestCommit(ITfContext *pic, std::wstring text, std::wstring replacing,
                                   ITfComposition *composition) {
    auto *s = new (std::nothrow)
        CommitEditSession(this, pic, std::move(text), std::move(replacing), composition);
    if (!s) {
        if (composition) composition->Release();
        return E_OUTOFMEMORY;
    }
    return Request(clientId_, pic, s);
}

HRESULT TextService::RequestSetComposition(ITfContext *pic, std::wstring text) {
    auto *s = new (std::nothrow) SetCompositionEditSession(this, pic, std::move(text));
    return s ? Request(clientId_, pic, s) : E_OUTOFMEMORY;
}

HRESULT TextService::RequestCancelComposition(ITfContext *pic) {
    auto *s = new (std::nothrow) CancelCompositionEditSession(this, pic);
    return s ? Request(clientId_, pic, s) : E_OUTOFMEMORY;
}

void TextService::SelectEnd(TfEditCookie ec, ITfContext *pic, ITfRange *range) {
    range->Collapse(ec, TF_ANCHOR_END);
    TF_SELECTION sel = {};
    sel.range = range;
    sel.style.ase = TF_AE_NONE;
    sel.style.fInterimChar = FALSE;
    pic->SetSelection(ec, 1, &sel);
}

void TextService::SetDisplayAttribute(TfEditCookie ec, ITfContext *pic, ITfRange *range, bool on) {
    if (displayAtom_ == TF_INVALID_GUIDATOM) return;
    ITfProperty *prop = nullptr;
    if (FAILED(pic->GetProperty(GUID_PROP_ATTRIBUTE, &prop)) || !prop) return;
    if (on) {
        VARIANT var;
        VariantInit(&var);
        var.vt = VT_I4;
        var.lVal = static_cast<LONG>(displayAtom_);
        prop->SetValue(ec, range, &var);
    } else {
        prop->Clear(ec, range);
    }
    prop->Release();
}

HRESULT TextService::CommitAt(TfEditCookie ec, ITfContext *pic, const std::wstring &text,
                              const std::wstring &replacing, ITfComposition *composition) {
    if (!pic) {
        if (composition) composition->Release();
        return E_INVALIDARG;
    }
    ITfComposition *comp = composition;
    if (!comp) {  // the current one, as of now
        comp = composition_;
        composition_ = nullptr;
    }

    // An open composition holds the provisional text: the committed text takes its place.
    if (comp) {
        ITfRange *range = nullptr;
        HRESULT hr = comp->GetRange(&range);
        if (SUCCEEDED(hr) && range) {
            SetDisplayAttribute(ec, pic, range, false);
            hr = range->SetText(ec, 0, text.c_str(), static_cast<LONG>(text.size()));
            SelectEnd(ec, pic, range);
            range->Release();
        }
        comp->EndComposition(ec);
        comp->Release();
        return hr;
    }

    // Otherwise the text replaces `replacing` just before the caret (a Sanskrit word or a
    // letter given an accent), checked first; if the caret has moved, nothing is replaced.
    if (!replacing.empty()) {
        TF_SELECTION sel = {};
        ULONG fetched = 0;
        if (FAILED(pic->GetSelection(ec, TF_DEFAULT_SELECTION, 1, &sel, &fetched)) || fetched != 1) {
            return E_FAIL;
        }
        ITfRange *range = sel.range;
        range->Collapse(ec, TF_ANCHOR_START);
        LONG moved = 0;
        HRESULT hr = range->ShiftStart(ec, -static_cast<LONG>(replacing.size()), &moved, nullptr);
        std::wstring before(replacing.size() + 1, L'\0');
        ULONG got = 0;
        if (SUCCEEDED(hr) && -moved == static_cast<LONG>(replacing.size())) {
            hr = range->GetText(ec, 0, before.data(), static_cast<ULONG>(replacing.size()), &got);
        }
        before.resize(got);
        if (SUCCEEDED(hr) && before == replacing) {
            hr = range->SetText(ec, 0, text.c_str(), static_cast<LONG>(text.size()));
            if (SUCCEEDED(hr)) SelectEnd(ec, pic, range);
        }
        range->Release();
        return hr;
    }

    if (text.empty()) return S_OK;
    ITfInsertAtSelection *insert = nullptr;
    if (FAILED(pic->QueryInterface(IID_ITfInsertAtSelection, (void **)&insert))) return E_FAIL;
    ITfRange *range = nullptr;
    HRESULT hr = insert->InsertTextAtSelection(ec, 0, text.c_str(), static_cast<LONG>(text.size()),
                                               &range);
    insert->Release();
    if (SUCCEEDED(hr) && range) {
        SelectEnd(ec, pic, range);
        range->Release();
    }
    return hr;
}

HRESULT TextService::StartCompositionAt(TfEditCookie ec, ITfContext *pic) {
    ITfInsertAtSelection *insert = nullptr;
    if (FAILED(pic->QueryInterface(IID_ITfInsertAtSelection, (void **)&insert))) return E_FAIL;
    ITfRange *range = nullptr;
    HRESULT hr = insert->InsertTextAtSelection(ec, TF_IAS_QUERYONLY, nullptr, 0, &range);
    insert->Release();
    if (FAILED(hr) || !range) return E_FAIL;

    ITfContextComposition *ctxComp = nullptr;
    hr = pic->QueryInterface(IID_ITfContextComposition, (void **)&ctxComp);
    if (SUCCEEDED(hr)) {
        ITfComposition *comp = nullptr;
        hr = ctxComp->StartComposition(ec, range, static_cast<ITfCompositionSink *>(this), &comp);
        ctxComp->Release();
        if (SUCCEEDED(hr) && comp) {
            composition_ = comp;
        } else if (SUCCEEDED(hr)) {
            hr = E_FAIL;  // the application refused a composition
        }
    }
    range->Release();
    return hr;
}

HRESULT TextService::SetCompositionAt(TfEditCookie ec, ITfContext *pic, const std::wstring &text) {
    if (!pic) return E_INVALIDARG;
    if (text.empty()) {
        CancelCompositionAt(ec);
        return S_OK;
    }
    if (!composition_) {
        HRESULT hr = StartCompositionAt(ec, pic);
        if (FAILED(hr)) return hr;
    }
    ITfRange *range = nullptr;
    if (FAILED(composition_->GetRange(&range)) || !range) return E_FAIL;
    HRESULT hr = range->SetText(ec, 0, text.c_str(), static_cast<LONG>(text.size()));
    if (SUCCEEDED(hr)) {
        SetDisplayAttribute(ec, pic, range, true);
        SelectEnd(ec, pic, range);
    }
    range->Release();
    return hr;
}

void TextService::CancelCompositionAt(TfEditCookie ec) {
    if (!composition_) return;
    // Clear the pointer first: ending is our own doing, not a termination.
    ITfComposition *comp = composition_;
    composition_ = nullptr;
    ITfRange *range = nullptr;
    if (SUCCEEDED(comp->GetRange(&range)) && range) {
        range->SetText(ec, 0, L"", 0);
        range->Release();
    }
    comp->EndComposition(ec);
    comp->Release();
}

STDMETHODIMP TextService::OnCompositionTerminated(TfEditCookie /*ecWrite*/,
                                                  ITfComposition *pComposition) {
    // The application ended the composition (a click elsewhere, for example): its text
    // stays in the document as it is, so the composer forgets it.
    if (composition_ && composition_ == pComposition) {
        composition_->Release();
        composition_ = nullptr;
    }
    host_.Reset();
    return S_OK;
}

// --- Focus --------------------------------------------------------------------

STDMETHODIMP TextService::OnInitDocumentMgr(ITfDocumentMgr * /*pdim*/) { return S_OK; }
STDMETHODIMP TextService::OnUninitDocumentMgr(ITfDocumentMgr * /*pdim*/) { return S_OK; }

STDMETHODIMP TextService::OnSetFocus(ITfDocumentMgr *pdimFocus, ITfDocumentMgr *pdimPrevFocus) {
    if (pdimFocus == pdimPrevFocus) return S_OK;
    // Finish what was being typed in the document being left, before anything is typed
    // in the next one.
    ITfContext *prev = nullptr;
    if (pdimPrevFocus) pdimPrevFocus->GetTop(&prev);
    CommitPendingInto(prev);
    if (prev) prev->Release();
    lastTest_ = {};
    if (pdimFocus) host_.OnActivate();
    return S_OK;
}

STDMETHODIMP TextService::OnPushContext(ITfContext * /*pic*/) { return S_OK; }
STDMETHODIMP TextService::OnPopContext(ITfContext * /*pic*/) { return S_OK; }

// --- Display attributes -------------------------------------------------------

STDMETHODIMP TextService::EnumDisplayAttributeInfo(IEnumTfDisplayAttributeInfo **ppEnum) {
    if (!ppEnum) return E_INVALIDARG;
    *ppEnum = new (std::nothrow) DisplayAttributeEnum();
    return *ppEnum ? S_OK : E_OUTOFMEMORY;
}

STDMETHODIMP TextService::GetDisplayAttributeInfo(REFGUID guid, ITfDisplayAttributeInfo **ppInfo) {
    if (!ppInfo) return E_INVALIDARG;
    *ppInfo = nullptr;
    if (!IsEqualGUID(guid, GUID_TTimeDisplayAttribute)) return E_INVALIDARG;
    *ppInfo = new (std::nothrow) DisplayAttributeInfo();
    return *ppInfo ? S_OK : E_OUTOFMEMORY;
}

HRESULT CreateTextService(IUnknown **ppunk) {
    if (!ppunk) return E_INVALIDARG;
    *ppunk = nullptr;
    TextService *svc = new (std::nothrow) TextService();
    if (!svc) return E_OUTOFMEMORY;
    *ppunk = static_cast<ITfTextInputProcessorEx *>(svc);
    return S_OK;
}
