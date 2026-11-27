import Cocoa

/// Fallback converter: paste or type, convert, copy. Used when Services cannot
/// replace selection (browsers, some Electron apps, etc.).
final class ConvertWindow: NSObject, NSWindowDelegate, NSTextViewDelegate {
    static let shared = ConvertWindow()

    private var window: NSWindow?
    private var inputView: NSTextView!
    private var outputView: NSTextView!
    private var directionPop: NSPopUpButton!
    private var usedLabel: NSTextField!
    private var copyButton: NSButton!

    func show(seed: String? = nil) {
        NSApp.setActivationPolicy(.regular)  // from a Service launch we start without a Dock icon
        if window == nil { build() }
        if let seed, !seed.isEmpty {
            inputView.string = seed
            runConvert()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep the singleton; next show reuses the window.
    }

    private func build() {
        let brutal = Prefs.brutal
        let paper: NSColor = brutal
            ? NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.05, green: 0.05, blue: 0.05, alpha: 1)
                : .white }
            : NSColor(srgbRed: 0.988, green: 0.906, blue: 0.914, alpha: 1)
        let ink: NSColor = brutal
            ? NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1)
                : NSColor(srgbRed: 0.05, green: 0.05, blue: 0.05, alpha: 1) }
            : NSColor(srgbRed: 0.66, green: 0.27, blue: 0.37, alpha: 1)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        w.title = "T-Time Converter"
        w.minSize = NSSize(width: 420, height: 320)
        w.center()
        w.delegate = self
        w.isReleasedWhenClosed = false
        if !brutal { w.backgroundColor = paper }
        w.appearance = brutal ? nil : NSAppearance(named: .aqua)

        let content = NSView(frame: w.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        w.contentView = content

        let title = NSTextField(labelWithString: "Converter")
        title.font = brutal
            ? NSFont(name: "Didot", size: 28) ?? .systemFont(ofSize: 28, weight: .regular)
            : .systemFont(ofSize: 22, weight: .bold)
        title.textColor = ink
        title.translatesAutoresizingMaskIntoConstraints = false

        let blurb = NSTextField(wrappingLabelWithString:
            "Paste Tibetan or Wylie (EWTS). Auto picks a direction from the script. When a host app cannot replace a selection, copy from here.")
        blurb.font = .systemFont(ofSize: 12)
        blurb.textColor = ink.withAlphaComponent(0.85)
        blurb.translatesAutoresizingMaskIntoConstraints = false

        directionPop = NSPopUpButton(frame: .zero, pullsDown: false)
        directionPop.translatesAutoresizingMaskIntoConstraints = false
        for d in ConvertDirection.allCases {
            directionPop.addItem(withTitle: d.shortTitle)
            directionPop.lastItem?.representedObject = d.rawValue
        }
        directionPop.target = self
        directionPop.action = #selector(directionChanged)

        let convertBtn = NSButton(title: "Convert", target: self, action: #selector(runConvert))
        convertBtn.translatesAutoresizingMaskIntoConstraints = false
        convertBtn.keyEquivalent = "\r"

        copyButton = NSButton(title: "Copy result", target: self, action: #selector(copyResult))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        // Cmd+Shift+C so Cmd+C still copies from the text views.
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = [.command, .shift]

        usedLabel = NSTextField(labelWithString: "")
        usedLabel.font = .systemFont(ofSize: 11)
        usedLabel.textColor = ink.withAlphaComponent(0.7)
        usedLabel.translatesAutoresizingMaskIntoConstraints = false

        inputView = makeEditor(tibetanSized: true)
        outputView = makeEditor(tibetanSized: true)
        outputView.isEditable = false

        let inScroll = scroll(for: inputView, placeholder: "Input")
        let outScroll = scroll(for: outputView, placeholder: "Result")
        let inCap = caption("Input", ink: ink, brutal: brutal)
        let outCap = caption("Result", ink: ink, brutal: brutal)

        let top = NSStackView(views: [directionPop, convertBtn, copyButton])
        top.orientation = .horizontal
        top.spacing = 8
        top.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(title)
        content.addSubview(blurb)
        content.addSubview(top)
        content.addSubview(usedLabel)
        content.addSubview(inCap)
        content.addSubview(inScroll)
        content.addSubview(outCap)
        content.addSubview(outScroll)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),

            blurb.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            blurb.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            blurb.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            top.topAnchor.constraint(equalTo: blurb.bottomAnchor, constant: 12),
            top.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            usedLabel.centerYAnchor.constraint(equalTo: top.centerYAnchor),
            usedLabel.leadingAnchor.constraint(equalTo: top.trailingAnchor, constant: 12),
            usedLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),

            inCap.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 14),
            inCap.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            inScroll.topAnchor.constraint(equalTo: inCap.bottomAnchor, constant: 4),
            inScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            inScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            inScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            outCap.topAnchor.constraint(equalTo: inScroll.bottomAnchor, constant: 12),
            outCap.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            outScroll.topAnchor.constraint(equalTo: outCap.bottomAnchor, constant: 4),
            outScroll.leadingAnchor.constraint(equalTo: inScroll.leadingAnchor),
            outScroll.trailingAnchor.constraint(equalTo: inScroll.trailingAnchor),
            outScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            outScroll.heightAnchor.constraint(equalTo: inScroll.heightAnchor),
        ])

        window = w
    }

    private func caption(_ s: String, ink: NSColor, brutal: Bool) -> NSTextField {
        let l = NSTextField(labelWithString: brutal ? s.uppercased() : s)
        l.font = brutal
            ? .systemFont(ofSize: 10, weight: .medium)
            : .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = ink.withAlphaComponent(0.8)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeEditor(tibetanSized: Bool) -> NSTextView {
        let t = NSTextView()
        t.isRichText = false
        t.font = tibetanSized ? TibetanFont.font(18) : .systemFont(ofSize: 14)
        t.delegate = self
        t.textContainerInset = NSSize(width: 6, height: 8)
        t.allowsUndo = true
        return t
    }

    private func scroll(for tv: NSTextView, placeholder: String) -> NSScrollView {
        let s = NSScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.hasVerticalScroller = true
        s.borderType = .bezelBorder
        s.documentView = tv
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.setAccessibilityLabel(placeholder)
        return s
    }

    private var selectedDirection: ConvertDirection {
        let raw = directionPop.selectedItem?.representedObject as? String ?? ConvertDirection.auto.rawValue
        return ConvertDirection(rawValue: raw) ?? .auto
    }

    @objc private func directionChanged() { runConvert() }

    @objc func runConvert() {
        let input = inputView.string
        let result = ConvertLogic.convert(input, direction: selectedDirection)
        outputView.string = result.text
        usedLabel.stringValue = input.isEmpty ? "" : "Used: \(result.used.shortTitle)"
        let tibetanOut = ConvertLogic.containsTibetan(result.text)
        outputView.font = TibetanFont.font(tibetanOut ? 20 : 14)
    }

    @objc private func copyResult() {
        let s = outputView.string
        guard !s.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    func textDidChange(_ notification: Notification) {
        // Live convert while typing; cheap for normal scholarly selections.
        runConvert()
    }
}
