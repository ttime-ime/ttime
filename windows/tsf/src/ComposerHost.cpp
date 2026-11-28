#include "ComposerHost.h"

namespace {

ttime_outcome EmptyOutcome() {
    ttime_outcome o = {};
    o.handled = false;
    return o;
}

bool Down(int vk) { return (GetKeyState(vk) & 0x8000) != 0; }

// Modifier and lock keys on their own: they change no text and must not commit
// the composition (on macOS they arrive as flag changes, not keys).
bool IsModifierOnly(WPARAM vk) {
    switch (vk) {
    case VK_CONTROL: case VK_LCONTROL: case VK_RCONTROL:
    case VK_MENU: case VK_LMENU: case VK_RMENU:
    case VK_LWIN: case VK_RWIN:
    case VK_CAPITAL: case VK_NUMLOCK: case VK_SCROLL:
        return true;
    default:
        return false;
    }
}

// Maps a key to a ttime key kind; for TTIME_KEY_TEXT fills `utf8`.
int MapKey(WPARAM vk, char *utf8, int utf8Cap) {
    switch (vk) {
    case VK_BACK: return TTIME_KEY_BACKSPACE;
    case VK_ESCAPE: return TTIME_KEY_ESCAPE;
    case VK_RETURN: return TTIME_KEY_ENTER;
    case VK_TAB: return TTIME_KEY_TAB;
    case VK_UP: return TTIME_KEY_UP;
    case VK_DOWN: return TTIME_KEY_DOWN;
    case VK_LEFT: return TTIME_KEY_LEFT;
    case VK_RIGHT: return TTIME_KEY_RIGHT;
    default: break;
    }

    // Shortcuts (Ctrl+S, Alt+F) belong to the application. Ctrl+Alt together is
    // AltGr on layouts that have it, which can type characters, so it is let through
    // to ToUnicode and judged by what it produces.
    const bool ctrl = Down(VK_CONTROL), alt = Down(VK_MENU);
    if ((ctrl || alt) && !(ctrl && alt)) return TTIME_KEY_OTHER;
    if (Down(VK_LWIN) || Down(VK_RWIN)) return TTIME_KEY_OTHER;

    BYTE state[256];
    if (!GetKeyboardState(state)) return TTIME_KEY_OTHER;
    WCHAR chars[8] = {};
    // Flag 0x4: do not change the keyboard's dead-key state (Windows 10 1607+), so
    // asking what the key types does not disturb what the application receives.
    int n = ToUnicode(static_cast<UINT>(vk), MapVirtualKeyW(static_cast<UINT>(vk), MAPVK_VK_TO_VSC),
                      state, chars, 8, 0x4);
    if (n <= 0) return TTIME_KEY_OTHER;  // dead key or not a character
    for (int i = 0; i < n; i++) {
        if (chars[i] < 0x20 || chars[i] == 0x7F) return TTIME_KEY_OTHER;  // control character
    }
    int bytes = WideCharToMultiByte(CP_UTF8, 0, chars, n, nullptr, 0, nullptr, nullptr);
    if (bytes <= 0 || bytes >= utf8Cap) return TTIME_KEY_OTHER;
    WideCharToMultiByte(CP_UTF8, 0, chars, n, utf8, utf8Cap, nullptr, nullptr);
    utf8[bytes] = 0;
    return TTIME_KEY_TEXT;
}

}  // namespace

ComposerHost::ComposerHost()
    : composer_(ttime_composer_new(false)),
      shiftTap_(ttime_shift_tap_new()),
      modeLock_(ttime_mode_lock_new()) {}

ComposerHost::~ComposerHost() {
    ttime_composer_free(composer_);
    ttime_shift_tap_free(shiftTap_);
    ttime_mode_lock_free(modeLock_);
}

void ComposerHost::Reset() {
    ttime_composer_reset(composer_);
    ttime_shift_tap_reset(shiftTap_);
}

void ComposerHost::OnActivate() {
    Reset();
    // Tibetan unless the mode is locked.
    ttime_outcome o = ttime_composer_set_latin(composer_, ttime_mode_lock_mode_on_focus(modeLock_));
    ttime_outcome_free(&o);
}

char *ComposerHost::CommitAll() { return ttime_composer_commit_all(composer_); }

bool ComposerHost::IsLatin() const { return ttime_composer_is_latin(composer_); }

bool ComposerHost::HandleShift(bool left, bool isKeyDown, double timeSec, ttime_outcome *out) {
    const int side = left ? 0 : 1;
    const bool chord = Down(VK_CONTROL) || Down(VK_MENU) || Down(VK_LWIN) || Down(VK_RWIN);
    *out = EmptyOutcome();
    if (isKeyDown) {
        // An auto-repeat of a Shift already down is not a new press.
        if (!ttime_shift_tap_held(shiftTap_, side)) {
            ttime_shift_tap_press(shiftTap_, side, timeSec, chord, ttime_shift_tap_held(shiftTap_, 1 - side));
        }
        return false;  // never take Shift: the application must see it
    }
    const int kind = ttime_shift_tap_release(shiftTap_, side, timeSec, chord);
    if (kind != 0 && left) {
        const int want = ttime_mode_lock_left_tap(modeLock_, kind, ttime_composer_is_latin(composer_));
        if (want >= 0) *out = ttime_composer_set_latin(composer_, want == 1);
    }
    return false;  // the release goes to the application too
}

bool ComposerHost::HandleKey(WPARAM wParam, LPARAM lParam, bool isKeyDown, ttime_outcome *out) {
    *out = EmptyOutcome();
    const double timeSec = static_cast<double>(GetTickCount64()) / 1000.0;

    // TSF usually reports VK_SHIFT; the scan code tells the sides apart (0x36 is right).
    if (wParam == VK_SHIFT || wParam == VK_LSHIFT || wParam == VK_RSHIFT) {
        bool left = wParam == VK_LSHIFT;
        if (wParam == VK_SHIFT) left = ((lParam >> 16) & 0xFF) != 0x36;
        return HandleShift(left, isKeyDown, timeSec, out);
    }
    if (!isKeyDown) return false;

    // Any other key, modifiers included, means a Shift held now is a chord.
    ttime_shift_tap_key_down(shiftTap_);
    if (IsModifierOnly(wParam)) return false;

    // Bit 30: the key was already down, so this is an auto-repeat (a long press).
    const bool repeat = (lParam & (1 << 30)) != 0;
    char utf8[16] = {};
    const int kind = MapKey(wParam, utf8, sizeof(utf8));
    *out = ttime_composer_handle(composer_, kind, kind == TTIME_KEY_TEXT ? utf8 : nullptr, repeat);
    return out->handled;
}
