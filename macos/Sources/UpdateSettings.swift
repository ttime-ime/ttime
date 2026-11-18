import Cocoa
import ServiceManagement

/// The user's update choices. Background updates are on unless the user turns them off.
enum UpdatePrefs {
    private static let d = UserDefaults.standard
    static var background: Bool {
        get { d.object(forKey: "UpdateInBackground") as? Bool ?? true }
        set { d.set(newValue, forKey: "UpdateInBackground") }
    }
    static var autoCheck: Bool {
        get { d.object(forKey: "UpdateAutoCheck") as? Bool ?? true }
        set { d.set(newValue, forKey: "UpdateAutoCheck") }
    }
    static var lastCheck: Date? {
        get { d.object(forKey: "UpdateLastCheck") as? Date }
        set { d.set(newValue, forKey: "UpdateLastCheck") }
    }
    static var offeredTag: String? {
        get { d.string(forKey: "UpdateOfferedTag") }
        set { d.set(newValue, forKey: "UpdateOfferedTag") }
    }
    static var offeredAt: Date? {
        get { d.object(forKey: "UpdateOfferedAt") as? Date }
        set { d.set(newValue, forKey: "UpdateOfferedAt") }
    }
}

/// Registers or unregisters the background helper to match the setting, offers
/// updates the helper will not install itself, and installs on request.
final class UpdateManager {
    static let shared = UpdateManager()
    static let plistName = "io.github.ttime-ime.inputmethod.TTime.UpdateHelper.plist"
    private var service: SMAppService { SMAppService.daemon(plistName: Self.plistName) }
    private var checking = false

    var currentVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0" }
    var helperStatus: SMAppService.Status { service.status }

    /// Brings the helper in line with the setting. Turning it on shows macOS's own
    /// approval notice the first time (System Settings, Login Items).
    func syncHelper() {
        let s = service
        if UpdatePrefs.background {
            if s.status == .notRegistered || s.status == .notFound {
                do { try s.register() } catch { DebugLog.log("helper register failed: \(error)") }
            }
        } else if s.status == .enabled || s.status == .requiresApproval {
            try? s.unregister()
        }
    }

    /// Called when the input method starts working: an automatic check when one is due.
    func checkIfDue() {
        syncHelper()
        guard UpdatePrefs.autoCheck, Updater.checkDue(last: UpdatePrefs.lastCheck, now: Date()) else { return }
        check(manual: false) { _ in }
    }

    enum Result { case upToDate, available(String), failed }

    /// Looks for an update. A manual check always answers; an automatic one only
    /// speaks up for a release not offered recently, and leaves it to the helper
    /// when the helper is going to install it.
    func check(manual: Bool, done: @escaping (Result) -> Void) {
        guard !checking else { return }
        checking = true
        UpdatePrefs.lastCheck = Date()
        DispatchQueue.global(qos: .utility).async {
            let releases = try? Updater.fetchReleases()
            let found = releases.flatMap { Updater.newest(in: $0, than: self.currentVersion) }
            DispatchQueue.main.async {
                self.checking = false
                guard releases != nil else { done(.failed); return }
                guard let release = found else { done(.upToDate); return }
                done(.available(release.tag))
                if !manual {
                    let now = Date()
                    guard Updater.offerDue(lastTag: UpdatePrefs.offeredTag, lastOffered: UpdatePrefs.offeredAt,
                                           tag: release.tag, now: now) else { return }
                    // Hold the prompt back for a day when the helper will install it.
                    let leave = UpdatePrefs.background && self.helperStatus == .enabled
                        && UpdatePrefs.offeredTag != release.tag
                    UpdatePrefs.offeredTag = release.tag
                    UpdatePrefs.offeredAt = now
                    if leave { return }
                }
                self.offer(release)
            }
        }
    }

    private func offer(_ release: Release) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "T-Time update available"
        alert.informativeText = "Version \(release.tag) is available (you have \(currentVersion))."
            + (Updater.installer(of: release) != nil ? "\n\nInstall it now? You'll be asked for your password once. Typing is not interrupted and nothing needs restarting." : "")
        if Updater.installer(of: release) != nil { _ = alert.addButton(withTitle: "Download & Install") }
        _ = alert.addButton(withTitle: "Release Notes")
        _ = alert.addButton(withTitle: "Later")
        let r = alert.runModal()
        let canInstall = Updater.installer(of: release) != nil
        if canInstall && r == .alertFirstButtonReturn {
            install(release)
        } else if (canInstall && r == .alertSecondButtonReturn) || (!canInstall && r == .alertFirstButtonReturn),
                  let url = URL(string: release.page) {
            NSWorkspace.shared.open(url)
        }
    }

    private func install(_ release: Release) {
        guard let asset = Updater.installer(of: release) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var message: String?
            do {
                let pkg = try Updater.download(asset, into: NSTemporaryDirectory())
                defer { try? FileManager.default.removeItem(atPath: pkg) }
                // One administrator prompt; the installer replaces the app in place.
                let script = "do shell script \"/usr/sbin/installer -pkg '\(pkg)' -target /\" with administrator privileges"
                var err: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&err)
                if let err = err {
                    if (err[NSAppleScript.errorNumber] as? Int) != -128 { message = "The installer did not finish." }
                }
            } catch {
                message = "The update could not be downloaded or verified."
            }
            guard let message = message else { return }
            DispatchQueue.main.async {
                let a = NSAlert()
                a.messageText = "Update failed"
                a.informativeText = message + " You can try again from the T-Time menu, Settings."
                a.runModal()
            }
        }
    }
}

/// The settings window. A normal window (not one of the non-activating panels):
/// it has real checkboxes and may take focus.
final class SettingsWindow: NSObject {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    private let background = NSButton(checkboxWithTitle: "Install updates in the background", target: nil, action: nil)
    private let auto = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let approval = NSButton(title: "Open Login Items…", target: nil, action: nil)
    private let checkNow = NSButton(title: "Check Now", target: nil, action: nil)
    private let result = NSTextField(labelWithString: "")

    func show() {
        if window == nil { build() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "T-Time Settings"
        w.isReleasedWhenClosed = false
        w.center()

        let heading = NSTextField(labelWithString: "Updates")
        heading.font = .boldSystemFont(ofSize: 13)
        background.target = self; background.action = #selector(toggleBackground)
        auto.target = self; auto.action = #selector(toggleAuto)
        approval.target = self; approval.action = #selector(openLoginItems)
        checkNow.target = self; checkNow.action = #selector(checkTapped)
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        result.font = .systemFont(ofSize: 11)
        result.textColor = .secondaryLabelColor
        let version = NSTextField(labelWithString: "T-Time \(UpdateManager.shared.currentVersion)")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor

        let row = NSStackView(views: [checkNow, result])
        row.spacing = 10
        let stack = NSStackView(views: [heading, background, status, approval, auto, row, version])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        status.preferredMaxLayoutWidth = 390
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: 440),
        ])
        w.contentView = content
        window = w
    }

    private func refresh() {
        background.state = UpdatePrefs.background ? .on : .off
        auto.state = UpdatePrefs.autoCheck ? .on : .off
        var text = ""
        var needsApproval = false
        if UpdatePrefs.background {
            switch UpdateManager.shared.helperStatus {
            case .enabled: text = "New versions are installed automatically, without interrupting typing or restarting your Mac."
            case .requiresApproval:
                text = "macOS needs your approval once: switch on T-Time under Login Items & Extensions. Until then you will be asked before an update is installed."
                needsApproval = true
            default: text = "The background updater is not running yet. It starts the next time T-Time is used."
            }
        } else {
            text = "You will be asked before an update is installed."
        }
        status.stringValue = text
        approval.isHidden = !needsApproval
    }

    @objc private func toggleBackground() {
        UpdatePrefs.background = background.state == .on
        UpdateManager.shared.syncHelper()
        refresh()
    }
    @objc private func toggleAuto() { UpdatePrefs.autoCheck = auto.state == .on }
    @objc private func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func checkTapped() {
        result.stringValue = "Checking…"
        UpdateManager.shared.check(manual: true) { [weak self] r in
            switch r {
            case .upToDate: self?.result.stringValue = "T-Time is up to date."
            case .available(let tag): self?.result.stringValue = "Version \(tag) is available."
            case .failed: self?.result.stringValue = "Could not reach the update server."
            }
        }
    }
}
