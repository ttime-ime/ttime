import AppKit

/// macOS Services provider. Host apps put the selection on a private pasteboard;
/// we convert and write the result back so the host can replace the selection.
final class ConvertService: NSObject {
    static let shared = ConvertService()

    @objc func convertAuto(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(.auto, pboard: pboard, error: error)
    }

    @objc func convertToTibetan(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(.toTibetan, pboard: pboard, error: error)
    }

    @objc func convertToWylie(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(.toWylie, pboard: pboard, error: error)
    }

    /// When macOS launched us just for a Service, quit shortly after it ran unless
    /// the converter window was opened meanwhile.
    static func scheduleQuitWhenIdle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if NSApp.activationPolicy() == .accessory { NSApp.terminate(nil) }
        }
    }

    private func run(_ direction: ConvertDirection, pboard: NSPasteboard,
                     error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let input = pboard.string(forType: .string) ?? pboard.string(forType: .init("public.utf8-plain-text")) else {
            error.pointee = "T-Time Tools: no text on the pasteboard." as NSString
            return
        }
        let result = ConvertLogic.convert(input, direction: direction)
        pboard.clearContents()
        pboard.setString(result.text, forType: .string)
        if NSApp.activationPolicy() == .accessory { Self.scheduleQuitWhenIdle() }
    }
}
