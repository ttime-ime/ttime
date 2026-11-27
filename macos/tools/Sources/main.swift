import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = ConvertService.shared
        NSUpdateDynamicServices()

        let args = CommandLine.arguments
        let wantWindow = args.contains("--window") || args.contains("--convert")
        // False when macOS launched us only to run a Service (or similar).
        let defaultLaunch = (notification.userInfo?["NSApplicationLaunchIsDefaultLaunchKey"] as? Bool) ?? true

        var seed: String?
        if let i = args.firstIndex(of: "--text"), args.index(after: i) < args.endIndex {
            seed = args[args.index(after: i)]
        }

        if wantWindow || defaultLaunch {
            ConvertWindow.shared.show(seed: seed)
        } else {
            // Started only to run a Service: no Dock icon, and quit when idle.
            NSApp.setActivationPolicy(.accessory)
            ConvertService.scheduleQuitWhenIdle()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { ConvertWindow.shared.show() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "ttime-tools" {
            var seed: String?
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let item = comps.queryItems?.first(where: { $0.name == "text" }) {
                seed = item.value
            }
            ConvertWindow.shared.show(seed: seed)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
