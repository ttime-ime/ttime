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
            // The helper runs as root, so it reads the signed-in user's choice from their
    // preferences file.
    var includePre = false
    var st = stat()
    if stat("/dev/console", &st) == 0, let pw = getpwuid(st.st_uid), st.st_uid != 0 {
        let plist = String(cString: pw.pointee.pw_dir) + "/Library/Preferences/io.github.ttime-ime.inputmethod.TTime.plist"
        includePre = (NSDictionary(contentsOfFile: plist)?["UpdatePrereleases"] as? Bool) ?? false
    }
    guard let release = Updater.newest(in: try Updater.fetchReleases(), than: current, includePrereleases: includePre) else {
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
