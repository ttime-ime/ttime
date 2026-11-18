import Foundation

// Background update helper. Registered as a LaunchDaemon (see the plist in
// Resources/LaunchDaemons) when the user keeps "install updates in the background"
// on. It runs as root every few hours, never shows anything, and logs to
// /var/log/TTimeUpdateHelper.log. Installing goes through the notarized installer
// package, so the update is applied exactly as a manual install would be.

func log(_ message: String) {
    FileHandle.standardError.write(Data("\(Date()) update helper: \(message)\n".utf8))
}

@main
struct UpdateHelper {
    static func main() {
        let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        log("checking (current \(current))")
        do {
            guard let release = Updater.newest(in: try Updater.fetchReleases(), than: current) else {
                log("up to date")
                exit(0)
            }
            guard let asset = Updater.installer(of: release) else {
                log("\(release.tag) has no installer package")
                exit(0)
            }
            let dir = NSTemporaryDirectory()
            log("downloading \(release.tag)")
            let pkg = try Updater.download(asset, into: dir)
            defer { try? FileManager.default.removeItem(atPath: pkg) }
            log("installing \(release.tag)")
            let r = Updater.run("/usr/sbin/installer", ["-pkg", pkg, "-target", "/"])
            guard r.status == 0 else { throw Updater.Failure.install(r.status) }
            log("installed \(release.tag)")
        } catch {
            log("FAILED: \(error)")
            exit(1)
        }
    }
}
