#pragma once

#include <msctf.h>
#include <windows.h>

#include <string>

#include "ComposerHost.h"

class TextService : public ITfTextInputProcessorEx,
                    public ITfKeyEventSink,
                    public ITfThreadMgrEventSink,
                    public ITfCompositionSink,
                    public ITfDisplayAttributeProvider {
public:
    TextService();
    ~TextService();

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

    // ITfTextInputProcessor
    STDMETHODIMP Activate(ITfThreadMgr *pThreadMgr, TfClientId tfClientId) override;
    STDMETHODIMP Deactivate() override;

    // ITfTextInputProcessorEx
    STDMETHODIMP ActivateEx(ITfThreadMgr *pThreadMgr, TfClientId tfClientId, DWORD dwFlags) override;

    // ITfKeyEventSink
    STDMETHODIMP OnSetFocus(BOOL fForeground) override;
    STDMETHODIMP OnTestKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) override;
    STDMETHODIMP OnTestKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) override;
    STDMETHODIMP OnKeyDown(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) override;
    STDMETHODIMP OnKeyUp(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL *pfEaten) override;
    STDMETHODIMP OnPreservedKey(ITfContext *pic, REFGUID rguid, BOOL *pfEaten) override;

    // ITfThreadMgrEventSink
    STDMETHODIMP OnInitDocumentMgr(ITfDocumentMgr *pdim) override;
    STDMETHODIMP OnUninitDocumentMgr(ITfDocumentMgr *pdim) override;
    STDMETHODIMP OnSetFocus(ITfDocumentMgr *pdimFocus, ITfDocumentMgr *pdimPrevFocus) override;
    STDMETHODIMP OnPushContext(ITfContext *pic) override;
    STDMETHODIMP OnPopContext(ITfContext *pic) override;

    // ITfCompositionSink
    STDMETHODIMP OnCompositionTerminated(TfEditCookie ecWrite, ITfComposition *pComposition) override;

    // ITfDisplayAttributeProvider (TSF asks a fresh, unactivated instance for these)
    STDMETHODIMP EnumDisplayAttributeInfo(IEnumTfDisplayAttributeInfo **ppEnum) override;
    STDMETHODIMP GetDisplayAttributeInfo(REFGUID guid, ITfDisplayAttributeInfo **ppInfo) override;

    TfClientId GetClientId() const { return clientId_; }
    bool IsComposing() const { return composition_ != nullptr; }

    // Called from edit sessions, with a valid cookie.
    HRESULT CommitAt(TfEditCookie ec, ITfContext *pic, const std::wstring &text,
                     const std::wstring &replacing, ITfComposition *composition);
    HRESULT SetCompositionAt(TfEditCookie ec, ITfContext *pic, const std::wstring &text);
    void CancelCompositionAt(TfEditCookie ec);

private:
    LONG ref_ = 1;
    ITfThreadMgr *threadMgr_ = nullptr;
    TfClientId clientId_ = TF_CLIENTID_NULL;
    DWORD threadMgrCookie_ = TF_INVALID_COOKIE;
    ITfComposition *composition_ = nullptr;
    TfGuidAtom displayAtom_ = TF_INVALID_GUIDATOM;
    ComposerHost host_;

    // TSF calls OnTestKey* first and OnKey* only for a key reported as eaten. Keys are
    // processed in OnTestKey* (so a key can commit text and still reach the
    // application, like Return); the matching OnKey* must not process them again.
    struct LastTest {
        bool valid = false;
        WPARAM wParam = 0;
        LPARAM lParam = 0;
        BOOL down = FALSE;
        BOOL eaten = FALSE;
    } lastTest_;

    bool InitKeyEventSink();
    void UninitKeyEventSink();
    bool InitThreadMgrEventSink();
    void UninitThreadMgrEventSink();
    void InitDisplayAttributeAtom();

    HRESULT HandleKey(ITfContext *pic, WPARAM wParam, LPARAM lParam, BOOL isDown, BOOL *pfEaten,
                      bool fromTest);
    HRESULT ApplyOutcome(ITfContext *pic, const ttime_outcome &outcome);
    // Commits what the composer holds into `pic`, finishing the open composition there.
    void CommitPendingInto(ITfContext *pic);

    HRESULT RequestCommit(ITfContext *pic, std::wstring text, std::wstring replacing,
                          ITfComposition *composition);
    HRESULT RequestSetComposition(ITfContext *pic, std::wstring text);
    HRESULT RequestCancelComposition(ITfContext *pic);

    HRESULT StartCompositionAt(TfEditCookie ec, ITfContext *pic);
    void SetDisplayAttribute(TfEditCookie ec, ITfContext *pic, ITfRange *range, bool on);
    void SelectEnd(TfEditCookie ec, ITfContext *pic, ITfRange *range);
};

HRESULT CreateTextService(IUnknown **ppunk);
