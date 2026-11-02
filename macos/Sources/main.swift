import Cocoa
import InputMethodKit

// The name must match InputMethodConnectionName in Info.plist.
let server = IMKServer(name: "TTime_Connection", bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
NSApplication.shared.run()
