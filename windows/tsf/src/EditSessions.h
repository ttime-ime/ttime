#pragma once

#include <msctf.h>
#include <string>

class TextService;

// An edit session keeps the service and the context alive until it has run, since
// TSF may run it after the request returns (TF_ES_ASYNCDONTCARE).
class EditSessionBase : public ITfEditSession {
public:
    EditSessionBase(TextService *service, ITfContext *context);
    virtual ~EditSessionBase();

    STDMETHODIMP QueryInterface(REFIID riid, void **ppvObj) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

protected:
    TextService *service_;
    ITfContext *context_;
    LONG ref_ = 1;
};

// Puts committed text into the document: in place of the open composition when
// there is one, else in place of `replacing` just before the caret, else at the caret.
// `composition`, when given, is the one to finish (its reference is taken over); when
// null, the service's current composition is used at the time the session runs.
class CommitEditSession : public EditSessionBase {
public:
    CommitEditSession(TextService *service, ITfContext *context, std::wstring text,
                      std::wstring replacing, ITfComposition *composition);
    ~CommitEditSession() override;
    STDMETHODIMP DoEditSession(TfEditCookie ec) override;

private:
    std::wstring text_;
    std::wstring replacing_;
    ITfComposition *composition_;
};

// Shows `text` as the composition (provisional text), starting one if needed.
class SetCompositionEditSession : public EditSessionBase {
public:
    SetCompositionEditSession(TextService *service, ITfContext *context, std::wstring text);
    STDMETHODIMP DoEditSession(TfEditCookie ec) override;

private:
    std::wstring text_;
};

// Removes the composition's text and ends it (Escape, or Backspace emptied it).
class CancelCompositionEditSession : public EditSessionBase {
public:
    CancelCompositionEditSession(TextService *service, ITfContext *context);
    STDMETHODIMP DoEditSession(TfEditCookie ec) override;
};
