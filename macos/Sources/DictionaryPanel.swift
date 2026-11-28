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

    /// Escape closes; Tab switches panels. Both are taken here before the page
    /// (which would otherwise steal Tab for its own focus cycle).
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isEmpty || flags == .shift {
                if event.keyCode == 53, let onEscape = onEscape {
                    onEscape()
                    return
                }
                if event.keyCode == 48, let onTab = onTab {
                    onTab()
                    return
                }
            }
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
    private var pageReady = false
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
        PanelTabs.fit(toNavigator: panel, tab: .dictionary)
        if !panel.isVisible { PanelTabs.place(panel, key: Self.originKey, topLeft: topLeft) }
        // Show the chrome first; look up on the next turn so Tab switching stays snappy.
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        let term = currentTerm?() ?? ""
        DispatchQueue.main.async { [weak self] in self?.lookUp(term) }
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
        case 48:
            // Tab is handled in KeyablePanel.sendEvent (before the page steals it).
            // Swallow a duplicate IMK delivery without cycling again.
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
        statusLabel.stringValue = term.isEmpty
            ? "Click the search box to type. Select Tibetan text, or put the caret after a syllable, to look it up from the document."
            : "Dictionary: Christian Steinert, dictionary.christian-steinert.de"
        if term.isEmpty {
            // Keep a warm homepage; avoid tearing down a page the user is reading.
            if web.url == nil, let home = URL(string: DictionaryLookup.site) {
                web.load(URLRequest(url: home))
            }
            return
        }
        guard term != loadedTerm, let url = DictionaryLookup.url(for: term) else { return }
        loadedTerm = term
        lastURL = url
        // Prefer in-page hash navigation (SPA). Full reload only when the shell is not ready.
        if pageReady || web.url != nil {
            navigateToTerm(term, in: web)
        } else {
            web.load(URLRequest(url: url))
        }
    }

    /// Push a new Tibetan term into the already-loaded SPA without `location.reload()`.
    private func navigateToTerm(_ term: String, in web: WKWebView) {
        guard let data = try? JSONSerialization.data(withJSONObject: [term]),
              let arr = String(data: data, encoding: .utf8) else {
            if let url = DictionaryLookup.url(for: term) { web.load(URLRequest(url: url)) }
            return
        }
        let js = """
        (function(term){
          try {
            var hash = '#/search/tib/' + encodeURIComponent(term) + '?activeTerm=' + encodeURIComponent(term);
            if (location.hash !== hash) location.hash = hash;
            var input = document.querySelector('input.searchTerm');
            if (input) {
              var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
              if (setter && setter.set) setter.set.call(input, term); else input.value = term;
              input.dispatchEvent(new Event('input', {bubbles:true}));
              input.dispatchEvent(new Event('change', {bubbles:true}));
            }
          } catch (e) {}
        })(\(arr)[0]);
        """
        web.evaluateJavaScript(js, completionHandler: nil)
    }

    /// The page runs in a separate WebKit process, which the system can end (memory,
    /// or because T-Time is a background application). That leaves a blank page and
    /// no crash report; bring the page back instead.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        DebugLog.log("dictionary web process terminated")
        pageReady = false
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
        pageReady = false
        statusLabel.stringValue = "The dictionary website could not be reached. It needs an internet connection."
    }

    // MARK: Building

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }
        let t = Theme.current

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        // The site's fixed top bar sits flush against the page edge, so the search
        // box's border and focus ring are cut off by the view; give it a margin.
        // Both refined themes inject a scoped stylesheet once at web-view creation.
        let css: String
        let dark = Theme.systemIsDark
        if t.brutal {
            let paper = dark ? "#0E0E0E" : "#FFFFFF"
            let ink = dark ? "#F2F2F2" : "#0E0E0E"
            let secondary = dark ? "#A3A3A3" : "#595959"
            let muted = dark ? "#8A8A8A" : "#767676"
            let border = dark ? "#3D3D3D" : "#CCCCCC"
            let hair = dark ? "#2A2A2A" : "#E0E0E0"
            css = """
            [class*='_topbar_']{box-sizing:border-box!important;padding:2px 0 4px 0!important;background:\(paper)!important;border-bottom:1px solid \(hair)!important;box-shadow:none!important;border-top:none!important;min-height:0!important}
            [class*='_textInputWrap_']{border:none!important;border-bottom:none!important;border-radius:0!important;background:transparent!important;box-shadow:none!important;min-height:28px!important;display:flex!important;align-items:center!important}
            input.searchTerm{font-family:Baskerville,Georgia,serif!important;font-size:17px!important;line-height:1.2!important;color:\(ink)!important;background:transparent!important;border:none!important;outline:none!important;padding:2px 2px!important;box-shadow:none!important}
            input.searchTerm:focus{box-shadow:none!important;outline:1px solid \(border)!important;outline-offset:2px!important}
            button.clear-input{color:\(muted)!important;background:transparent!important;border:none!important;box-shadow:none!important;opacity:0.9!important;font-size:14px!important;transform:none!important}
            [class*='_triggerBtn_']{color:\(muted)!important;background:transparent!important;border:none!important;box-shadow:none!important;opacity:0.7!important;transform:scale(0.88)!important}
            body,.page,.contentArea,.mainWrap{background:\(paper)!important;color:\(ink)!important}
            .definitionHead,.definitionHeadtib{font-family:'Noto Serif Tibetan',serif!important;font-size:40px!important;line-height:1.3!important;color:\(ink)!important;margin:6px 0 6px 0!important;font-weight:400!important;padding:0!important}
            .dictName{font-family:-apple-system,BlinkMacSystemFont,sans-serif!important;font-size:10px!important;font-weight:500!important;letter-spacing:0.12em!important;text-transform:uppercase!important;color:\(secondary)!important;border:none!important;text-decoration:none!important;border-bottom:none!important;margin:10px 0 1px 0!important;padding:4px 0 0 0!important;border-top:none!important}
            .dictName:first-of-type{margin-top:2px!important;padding-top:0!important}
            .dictName *{text-decoration:none!important;border-bottom:none!important}
            .definition,.definitions{font-family:Baskerville,Georgia,'Noto Serif Tibetan',serif!important;font-size:15px!important;line-height:1.38!important;color:\(ink)!important;margin:0 0 2px 0!important;padding:0!important;text-indent:0!important;margin-left:0!important;padding-left:0!important}
            .definitions{border-top:none!important;padding-left:0!important;margin-left:0!important}
            .wrapDefinitionView,.mainWrap.wrapDefinitionView{padding-left:0!important}
            a.link,.link{color:\(ink)!important;text-decoration:underline!important;text-underline-offset:2px!important}
            .sideBarInnerWrap,.title,.subtitle{color:\(muted)!important}
            .sideBar,[class*='sideBar'],[class*='SideBar']{display:none!important}
            img,video,iframe{content-visibility:auto!important;max-width:100%!important}
            *{animation:none!important;transition:none!important}
            """
        } else {
            // Bubblegum confectionery reading surface (Nunito + cream / cherry).
            let paper = dark ? "#302029" : "#FBE8EC"
            let surface = dark ? "#392630" : "#FFF8F6"
            let tile = dark ? "#49303B" : "#FFF0E2"
            let ink = dark ? "#F8DCE4" : "#773047"
            let secondary = dark ? "#D5A5B6" : "#A65A72"
            let muted = dark ? "#B88A9A" : "#C07A90"
            let border = dark ? "#79505F" : "#EDB2BE"
            // Darker raspberry for source labels (was too bright #E98CA4).
            let source = dark ? "#E0A0B4" : "#A34465"
            let selection = dark ? "#AD4267" : "#A33D60"
            css = """
            [class*='_topbar_']{box-sizing:border-box!important;padding:6px 10px 8px 10px!important;background:\(paper)!important;border-bottom:1px solid \(border)!important;box-shadow:none!important;border-top:none!important;min-height:0!important;display:flex!important;align-items:center!important}
            [class*='_textInputWrap_']{border:1px solid \(border)!important;border-radius:12px!important;background:\(tile)!important;box-shadow:none!important;min-height:34px!important;height:34px!important;max-height:34px!important;display:flex!important;align-items:center!important;padding:0 36px 0 10px!important;gap:0!important;box-sizing:border-box!important;position:relative!important;overflow:visible!important}
            input.searchTerm{font-family:Nunito,'Avenir Next Rounded',-apple-system,sans-serif!important;font-size:14px!important;line-height:20px!important;height:20px!important;color:\(ink)!important;background:transparent!important;border:none!important;outline:none!important;padding:0 4px!important;margin:0!important;box-shadow:none!important;flex:1 1 auto!important;min-width:0!important;align-self:center!important}
            input.searchTerm::placeholder{color:\(muted)!important;opacity:1!important;font-family:Nunito,-apple-system,sans-serif!important;font-size:13px!important;line-height:20px!important}
            input.searchTerm:focus{box-shadow:none!important;outline:none!important}
            button.clear-input,button.clear-input *{color:\(secondary)!important;background:transparent!important;border:none!important;box-shadow:none!important;opacity:0.95!important;font-size:14px!important;line-height:28px!important;margin:0!important;padding:0!important;vertical-align:middle!important}
            /* Pin with top/bottom + margin:auto (avoids transform/inset fights with the site). */
            button.clear-input{position:absolute!important;left:auto!important;right:30px!important;top:0!important;bottom:0!important;transform:none!important;width:28px!important;height:28px!important;min-width:28px!important;max-height:28px!important;margin:auto 0!important;padding:0!important;display:flex!important;align-items:center!important;justify-content:center!important;align-self:center!important}
            [class*='_triggerBtn_'],[class*='_triggerBtn_'] *{color:\(secondary)!important;background:transparent!important;border:none!important;box-shadow:none!important;opacity:0.85!important;margin:0!important;padding:0!important;line-height:28px!important}
            [class*='_triggerBtn_']{position:absolute!important;left:auto!important;right:4px!important;top:0!important;bottom:0!important;transform:none!important;width:28px!important;height:28px!important;min-width:28px!important;max-height:28px!important;margin:auto 0!important;padding:0!important;display:flex!important;align-items:center!important;justify-content:center!important;align-self:center!important}
            body,.page,.contentArea,.mainWrap{background:\(surface)!important;color:\(ink)!important;font-family:Nunito,-apple-system,sans-serif!important}
            .definitionHead,.definitionHeadtib{font-family:'Noto Serif Tibetan',serif!important;font-size:36px!important;line-height:1.32!important;color:\(ink)!important;margin:10px 0 10px 0!important;font-weight:400!important;padding:0!important}
            .dictName{font-family:Nunito,-apple-system,sans-serif!important;font-size:12px!important;font-weight:700!important;letter-spacing:0.02em!important;text-transform:none!important;color:\(source)!important;border:none!important;text-decoration:none!important;border-bottom:none!important;margin:12px 0 4px 0!important;padding:0!important;border-top:none!important}
            .dictName:first-of-type{margin-top:6px!important}
            .dictName *{text-decoration:none!important;border-bottom:none!important;color:\(source)!important}
            .definition,.definitions{font-family:Nunito,-apple-system,'Noto Serif Tibetan',sans-serif!important;font-size:14px!important;line-height:1.42!important;color:\(ink)!important;margin:0 0 2px 0!important;padding:0!important;text-indent:0!important;margin-left:0!important;padding-left:0!important}
            .definitions{border-top:none!important;padding-left:0!important;margin-left:0!important;margin-bottom:12px!important}
            .wrapDefinitionView,.mainWrap.wrapDefinitionView{padding:10px 14px 18px 14px!important;background:\(surface)!important;border-radius:14px!important;box-sizing:border-box!important}
            .page,.contentArea,.mainWrap{padding-left:0!important;padding-right:0!important}
            a.link,.link{color:\(selection)!important;text-decoration:underline!important;text-underline-offset:2px!important}
            .sideBarInnerWrap,.title,.subtitle,.helpText,p,li{color:\(secondary)!important;font-family:Nunito,-apple-system,sans-serif!important}
            .title{font-size:18px!important;font-weight:700!important;color:\(ink)!important;line-height:1.3!important;margin:10px 0 6px 0!important}
            .subtitle{font-size:13px!important;font-weight:500!important;color:\(secondary)!important;line-height:1.4!important;margin:0 0 8px 0!important}
            .sideBar,[class*='sideBar'],[class*='SideBar']{display:none!important}
            img,video,iframe{content-visibility:auto!important;max-width:100%!important}
            *{animation:none!important;transition:none!important}
            """
        }
        let escaped = css.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "")
        let js = "var s=document.createElement('style');s.setAttribute('data-ttime','1');s.textContent=\"\(escaped)\";(document.head||document.documentElement).appendChild(s);"
        // Inject before paint so Brutalist restyle does not flash the heavy site chrome.
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let web = PassiveWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.translatesAutoresizingMaskIntoConstraints = false
        web.setValue(false, forKey: "drawsBackground")
        web.wantsLayer = true
        // Not artwork: keep a slight radius so the page edge is not a hard clip.
        web.layer?.cornerRadius = t.bubblegum ? 14 : (t.brutal ? t.cellRadius : 12)
        web.layer?.masksToBounds = true
        web.setContentHuggingPriority(.init(1), for: .vertical)
        web.setContentCompressionResistancePriority(.init(1), for: .vertical)
        web.setContentHuggingPriority(.init(1), for: .horizontal)
        web.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        self.web = web

        // The same title, tabs and close button as the other panels.
        let header = PanelTabs.makeHeader(selected: .dictionary, panel: { [weak self] in self?.panel }) { [weak self] in self?.close() }

        statusLabel.font = t.bubblegum ? BubblegumFonts.ui(10, weight: .medium) : NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = t.mutedText
        statusLabel.maximumNumberOfLines = 2
        statusLabel.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        var body: [NSView] = [header, web]
        if t.usesComposeLayout {
            let rule = RuleView(vertical: false)
            body.append(rule)
        }
        body.append(statusLabel)
        let root = NSStackView(views: body)
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = t.rootSpacing
        root.edgeInsets = PanelTabs.insets
        root.translatesAutoresizingMaskIntoConstraints = false
        for v in [header, web, statusLabel] {
            v.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -(PanelTabs.insets.left + PanelTabs.insets.right)).isActive = true
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
        grip.constrain = { wanted in PanelTabs.proposed(wanted, tab: .dictionary) }
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
        panel.onTab = { [weak self] in PanelTabs.cycle(from: .dictionary, panel: self?.panel) }
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
