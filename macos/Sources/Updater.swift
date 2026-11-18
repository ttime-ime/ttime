import Foundation
import CryptoKit

/// Update logic shared by the input method (which offers updates) and the background
/// helper (which installs them unattended). Foundation only, so it is testable.

struct ReleaseAsset: Equatable {
    var name: String
    var url: String
    var sha256: String  // lowercase hex, or empty if GitHub published no digest
}

struct Release: Equatable {
    var tag: String
    var page: String
    var prerelease: Bool
    var draft: Bool
    var assets: [ReleaseAsset]
}

/// A version such as `0.1.0` or `0.1.0-rc.2`. A prerelease sorts before its release.
struct AppVersion: Comparable, Equatable {
    var numbers: [Int]
    var pre: [String]  // empty for a final release

    init?(_ text: String) {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        if let plus = s.firstIndex(of: "+") { s = String(s[..<plus]) }
        let parts = s.split(separator: "-", maxSplits: 1).map(String.init)
        guard let core = parts.first else { return nil }
        let nums = core.split(separator: ".").map { Int($0) }
        guard !nums.isEmpty, !nums.contains(where: { $0 == nil }) else { return nil }
        numbers = nums.map { $0! }
        pre = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
    }

    var isPrerelease: Bool { !pre.isEmpty }

    static func < (a: AppVersion, b: AppVersion) -> Bool {
        let n = max(a.numbers.count, b.numbers.count)
        for i in 0..<n {
            let x = i < a.numbers.count ? a.numbers[i] : 0
            let y = i < b.numbers.count ? b.numbers[i] : 0
            if x != y { return x < y }
        }
        if a.pre.isEmpty != b.pre.isEmpty { return !a.pre.isEmpty }  // 1.0-rc < 1.0
        for (p, q) in zip(a.pre, b.pre) where p != q {
            if let pi = Int(p), let qi = Int(q) { return pi < qi }
            if Int(p) != nil { return true }  // numeric identifiers sort first
            if Int(q) != nil { return false }
            return p < q
        }
        return a.pre.count < b.pre.count
    }
}

enum Updater {
    static let releasesURL = "https://api.github.com/repos/ttime-ime/ttime/releases?per_page=30"

    /// Parses `GET /repos/.../releases`. Unknown fields are ignored.
    static func parse(_ json: Data) -> [Release] {
        guard let list = (try? JSONSerialization.jsonObject(with: json)) as? [[String: Any]] else { return [] }
        return list.compactMap { d in
            guard let tag = d["tag_name"] as? String else { return nil }
            let assets = (d["assets"] as? [[String: Any]] ?? []).compactMap { a -> ReleaseAsset? in
                guard let name = a["name"] as? String, let url = a["browser_download_url"] as? String else { return nil }
                var digest = (a["digest"] as? String) ?? ""
                if digest.hasPrefix("sha256:") { digest.removeFirst(7) }
                return ReleaseAsset(name: name, url: url, sha256: digest.lowercased())
            }
            return Release(tag: tag, page: d["html_url"] as? String ?? "",
                           prerelease: d["prerelease"] as? Bool ?? false,
                           draft: d["draft"] as? Bool ?? false, assets: assets)
        }
    }

    /// The newest release strictly newer than `current`, staying on the installed
    /// build's channel: a final build only moves to final releases, a prerelease
    /// build also follows prereleases.
    static func newest(in releases: [Release], than current: String) -> Release? {
        guard let cur = AppVersion(current) else { return nil }
        let allowPre = cur.isPrerelease
        return releases
            .filter { !$0.draft }
            .compactMap { r -> (AppVersion, Release)? in
                guard let v = AppVersion(r.tag), v > cur else { return nil }
                if (v.isPrerelease || r.prerelease) && !allowPre { return nil }
                return (v, r)
            }
            .max { $0.0 < $1.0 }?.1
    }

    /// The installer package of a release: `T-Time-<version>.pkg`. An unsigned
    /// development package is never offered.
    static func installer(of release: Release) -> ReleaseAsset? {
        release.assets.first {
            $0.name.hasPrefix("T-Time-") && $0.name.hasSuffix(".pkg") && !$0.name.contains("UNSIGNED")
        }
    }

    // MARK: Timing

    static let checkInterval: TimeInterval = 6 * 3600
    static let offerInterval: TimeInterval = 24 * 3600

    /// Whether an automatic check is due.
    static func checkDue(last: Date?, now: Date) -> Bool {
        guard let last = last else { return true }
        return now.timeIntervalSince(last) >= checkInterval || last > now
    }

    /// Check often, ask rarely: the same release is offered at most once a day, a
    /// newer one at the next check.
    static func offerDue(lastTag: String?, lastOffered: Date?, tag: String, now: Date) -> Bool {
        guard let lastTag = lastTag, let lastOffered = lastOffered, lastTag == tag else { return true }
        return now.timeIntervalSince(lastOffered) >= offerInterval || lastOffered > now
    }

    // MARK: Network and files (blocking; call off the main thread)

    enum Failure: Error, CustomStringConvertible {
        case network(String), digest(String), install(Int32)
        var description: String {
            switch self {
            case .network(let m): return "network: \(m)"
            case .digest(let m): return "digest mismatch: \(m)"
            case .install(let c): return "installer exited with status \(c)"
            }
        }
    }

    static func run(_ tool: String, _ args: [String]) -> (status: Int32, out: Data) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return (-1, Data()) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, data)
    }

    static func fetchReleases() throws -> [Release] {
        let r = run("/usr/bin/curl", ["-fsSL", "--max-time", "30", "-H", "Accept: application/vnd.github+json", releasesURL])
        guard r.status == 0 else { throw Failure.network("curl exit \(r.status)") }
        return parse(r.out)
    }

    static func sha256(ofFile path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Downloads an installer into `dir` and checks it against GitHub's digest when
    /// one was published (macOS still verifies the installer's own signature).
    static func download(_ asset: ReleaseAsset, into dir: String) throws -> String {
        let safe = String(asset.name.map { $0.isLetter || $0.isNumber || ".-_".contains($0) ? $0 : "_" })
        let dest = (dir as NSString).appendingPathComponent("update-" + safe)
        try? FileManager.default.removeItem(atPath: dest)
        let r = run("/usr/bin/curl", ["-fsSL", "--max-time", "600", "-o", dest, asset.url])
        guard r.status == 0 else { throw Failure.network("download failed (curl exit \(r.status))") }
        if !asset.sha256.isEmpty, sha256(ofFile: dest) != asset.sha256 {
            try? FileManager.default.removeItem(atPath: dest)
            throw Failure.digest(asset.name)
        }
        return dest
    }
}
