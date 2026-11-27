import Cocoa
final class DictionaryPanel: NSObject {
    static var shared = DictionaryPanel()
    static func rebuild() {}
    var isOpen: Bool { false }
    var window: NSPanel? { nil }
    func open(topLeft: NSPoint? = nil) {}
    func close() {}
}
