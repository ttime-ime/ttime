import Cocoa
import WebKit

/// A web view that takes the first click even when its panel was not key, and
/// does not let the click move the window.
private final class PassiveWebView: WKWebView, OwnsMouse {
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A panel that can take the keyboard when you click into the page (to type in
/// the site's search box), without activating T-Time's own application, so the
/// document's application stays frontmost.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Escape closes the panel whatever the page is doing (even with a menu open
    /// or a field focused). Taken here, before the page or the input method sees it.
    var onEscape: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53, let onEscape = onEscape {
            onEscape()
            return
        }
        super.sendEvent(event)
    }

    /// T-Time has no menu bar, so nothing maps Command+V and friends to the
    /// editing actions; do it here, for the page's focused field.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.option), !flags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        let action: Selector?
        switch (key, flags.contains(.shift)) {
        case ("v", false): action = #selector(NSText.paste(_:))
        case ("c", false): action = #selector(NSText.copy(_:))
        case ("x", false): action = #selector(NSText.cut(_:))
        case ("a", false): action = #selector(NSText.selectAll(_:))
        case ("z", false): action = Selector(("undo:"))
        case ("z", true): action = Selector(("redo:"))
        default: action = nil
        }
        if let action = action, NSApp.sendAction(action, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// The dictionary tab: Christian Steinert's Tibetan-English dictionary, shown from
/// its own website (`DictionaryLookup`). Nothing from it is bundled, and nothing
/// is requested until the tab is opened; opening it sends the term (the
/// selection, or the syllable before the caret) to that site.
///
/// It does not take focus when it opens: the document keeps the caret and the term
/// comes from there. Click into the page and it takes the keyboard like any
/// window (scrolling, menus, dragging and the search box all work, and T-Time's
/// EWTS typing applies in the box). Click back into the document, or close the
/// panel, and the document's application has the keyboard again.
final class DictionaryPanel: NSObject, WKNavigationDelegate {
    static var shared = DictionaryPanel()

    static func rebuild() {
        let old = shared
        let wasOpen = old.isOpen
        let tl = old.panel.map { PanelTabs.topLeft(of: $0) }
        old.pendingClose?.cancel()
        old.panel?.orderOut(nil)
        let new = DictionaryPanel()
        new.currentTerm = old.currentTerm
        shared = new
        if wasOpen { new.open(topLeft: tl) }
    }

    /// The term to look up now; set by the active controller.
    var currentTerm: (() -> String)?

    private static let originKey = PanelTabs.originKey

    private var panel: NSPanel?
    private var pendingClose: DispatchWorkItem?
    private var web: PassiveWebView?
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private var loadedTerm = ""
    private var lastURL: URL?
    /// Whether you have clicked into the page since it opened. Then it stays until you
    /// close it (Esc, the close button, or the shortcut) instead of going when the
    /// document loses focus: you were reading it, not typing in the document.
    private var engaged = false

    var isOpen: Bool { panel?.isVisible ?? false }
    var window: NSPanel? { panel }
    /// Whether the page, not the document, has the keyboard.
    var hasKeyboard: Bool { panel?.isKeyWindow ?? false }

    // MARK: Showing

    func open(topLeft: NSPoint? = nil) {
        pendingClose?.cancel()
        if !isOpen { engaged = false }
        let panel = ensurePanel()
        PanelTabs.fit(toNavigator: panel)
        if !panel.isVisible { PanelTabs.place(panel, key: Self.originKey, topLeft: topLeft) }
        lookUp(currentTerm?() ?? "")
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    func close() {
        pendingClose?.cancel()
        guard let panel = panel else { return }
        // If the page had the keyboard, give it back to the document's application.
        let host = panel.isKeyWindow ? NSWorkspace.shared.frontmostApplication : nil
        panel.orderOut(nil)
        host?.activate(options: [])
    }

    func toggle() { isOpen ? close() : open() }

    func scheduleClose() {
        guard isOpen, !engaged else { return }
        pendingClose?.cancel()
        // Not while you are using the page: the document lost the keyboard to it.
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.panel?.isKeyWindow != true else { return }
            self.panel?.orderOut(nil)
        }
        pendingClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func cancelClose() { pendingClose?.cancel() }

    // MARK: Keys

    /// Escape closes and Tab moves to the next panel; every other key goes on to
    /// the document.
    func handle(_ key: KeyInput) -> Bool {
        guard isOpen else { return false }
        // The page has the keyboard (Tab moves in it; Esc is taken by the panel itself).
        if panel?.isKeyWindow == true { return false }
        switch key {
        case .escape:
            close()
            return true
        case .tab:
            PanelTabs.cycle(from: .dictionary, panel: panel)
            return true
        default:
            return false
        }
    }

    /// Puts a key typed while the page has the keyboard straight into the page.
    /// Returns false for keys left to the system (Command shortcuts).
    func type(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) { return false }
        let js: String
        switch event.keyCode {
        case 48:  // Tab
            PanelTabs.cycle(from: .dictionary, panel: panel)
            return true
        case 51: js = "document.execCommand('delete')"
        case 117: js = "document.execCommand('forwardDelete')"
        case 123: js = "getSelection().modify('move','backward','character')"
        case 124: js = "getSelection().modify('move','forward','character')"
        case 125, 126: return true  // up/down: the page scrolls with the wheel
        case 36, 76:  // Return
            js = """
            (function(){var e=document.activeElement;if(!e)return;
            ['keydown','keypress','keyup'].forEach(function(t){e.dispatchEvent(new KeyboardEvent(t,{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}))});
            if(e.tagName==='BUTTON'||e.tagName==='A')e.click();})()
            """
        default:
            guard let chars = event.characters, !chars.isEmpty,
                  chars.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 && !(0xF700...0xF8FF).contains($0.value) }),
                  let data = try? JSONSerialization.data(withJSONObject: [chars]),
                  let arr = String(data: data, encoding: .utf8) else { return true }
            js = "document.execCommand('insertText', false, \(arr)[0])"
        }
        web?.evaluateJavaScript(js, completionHandler: nil)
        return true
    }

    // MARK: Looking up

    private func lookUp(_ term: String) {
        guard let web = web else { return }
        if term.isEmpty {
            // Nothing selected: keep what is showing, or open the dictionary
            // itself so there is a search box to click into and type in.
            if web.url == nil, let home = URL(string: DictionaryLookup.site) {
                web.load(URLRequest(url: home))
            }
            statusLabel.stringValue = "Click the search box to type. Select Tibetan text, or put the caret after a syllable, to look it up from the document."
            return
        }
        guard term != loadedTerm, let url = DictionaryLookup.url(for: term) else {
            statusLabel.stringValue = "Dictionary: Christian Steinert, dictionary.christian-steinert.de"
            return
        }
        loadedTerm = term
        lastURL = url
        statusLabel.stringValue = "Dictionary: Christian Steinert, dictionary.christian-steinert.de"
        // The site reads the term from the address once, when the page loads, to
        // fill its search box; a new term in an already loaded page must reload it.
        if web.url != nil, let fragment = url.fragment,
           let data = try? JSONSerialization.data(withJSONObject: [fragment]),
           let arr = String(data: data, encoding: .utf8) {
            web.evaluateJavaScript("location.hash = \(arr)[0]; location.reload();", completionHandler: nil)
        } else {
            web.load(URLRequest(url: url))
        }
    }

    /// The page runs in a separate WebKit process, which the system can end (memory,
    /// or because T-Time is a background application). That leaves a blank page and
    /// no crash report; bring the page back instead.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        DebugLog.log("dictionary web process terminated")
        statusLabel.stringValue = "The page stopped; reloading…"
        if webView.url != nil {
            webView.reload()
        } else if let url = lastURL ?? URL(string: DictionaryLookup.site) {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed() }
    private func failed() {
        loadedTerm = ""  // so the next open tries again
        statusLabel.stringValue = "The dictionary website could not be reached. It needs an internet connection."
    }

    // MARK: Building

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }
        let t = Theme.current

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // The site's fixed top bar sits flush against the page edge, so the search
        // box's border and focus ring are cut off by the view; give it a margin.
        let css = "[class*='_topbar_']{box-sizing:border-box!important;padding:4px 4px 0 4px!important}"
        let js = "var s=document.createElement('style');s.textContent=\"\(css)\";(document.head||document.documentElement).appendChild(s);"
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let web = PassiveWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.translatesAutoresizingMaskIntoConstraints = false
        web.setValue(false, forKey: "drawsBackground")
        web.wantsLayer = true
        web.layer?.cornerRadius = t.brutal ? 4 : 12
        web.layer?.masksToBounds = true
        web.setContentHuggingPriority(.init(1), for: .vertical)
        web.setContentCompressionResistancePriority(.init(1), for: .vertical)
        web.setContentHuggingPriority(.init(1), for: .horizontal)
        web.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        self.web = web

        // The same title, tabs and close button as the other panels.
        let header = PanelTabs.makeHeader(selected: .dictionary, panel: { [weak self] in self?.panel }) { [weak self] in self?.close() }

        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = t.ink.withAlphaComponent(0.7)
        statusLabel.maximumNumberOfLines = 2
        statusLabel.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        let root = NSStackView(views: [header, web, statusLabel])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 9
        root.edgeInsets = PanelTabs.insets
        root.translatesAutoresizingMaskIntoConstraints = false
        for v in [header, web, statusLabel] {
            v.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -44).isActive = true
        }

        let container = DraggableView()
        container.wantsLayer = true
        container.layer?.backgroundColor = container.resolved(t.paper)
        container.layer?.cornerRadius = t.panelRadius
        container.layer?.borderWidth = t.panelBorder
        container.layer?.borderColor = container.resolved(t.panelBorderColor)
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            web.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        let grip = ResizeGrip()
        grip.constrain = { wanted in PanelTabs.proposed(wanted) }
        container.addSubview(grip)
        NSLayoutConstraint.activate([
            grip.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
            grip.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
        ])

        let panel = KeyablePanel(contentRect: NSRect(origin: .zero, size: NSSize(width: PanelTabs.width, height: 560)),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = container
        panel.onEscape = { [weak self] in self?.close() }
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false  // the header and margins drag it; the page is the page's
        panel.appearance = t.appearance
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setAccessibilityLabel("T-Time dictionary")
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(panelMoved), name: name, object: panel)
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
            self?.engaged = true
        }
        self.panel = panel
        return panel
    }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel else { return }
        PanelTabs.save(panel, key: Self.originKey)
    }
}
