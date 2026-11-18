import Cocoa
import InputMethodKit
import Carbon

/// `TTime --register`: tells macOS about the installed input source and enables it,
/// without selecting it, so an install or update shows up without a logout. Run by the
/// installer in the user's session.
if CommandLine.arguments.contains("--register") {
    let url = Bundle.main.bundleURL as CFURL
    let status = TISRegisterInputSource(url)
    let filter = [kTISPropertyBundleID as String: Bundle.main.bundleIdentifier ?? ""] as CFDictionary
    if let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] {
        for source in list { TISEnableInputSource(source) }
    }
    exit(status == noErr ? 0 : 1)
}

// The name must match InputMethodConnectionName in Info.plist.
let server = IMKServer(name: "TTime_Connection", bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
DispatchQueue.main.async { UpdateManager.shared.checkIfDue() }
NSApplication.shared.run()
