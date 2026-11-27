import AppIntents
import Foundation

/// Actions for the Shortcuts app. After install, they also appear when a Shortcut
/// is offered as a Service that replaces selected text.
struct ConvertAutoIntent: AppIntent {
    static var title: LocalizedStringResource = "T-Time Auto-convert"
    static var description = IntentDescription("Convert between Tibetan script and Wylie (EWTS), choosing direction from the text.")

    @Parameter(title: "Text")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Auto-convert \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: ConvertLogic.convert(text, direction: .auto).text)
    }
}

struct ConvertToTibetanIntent: AppIntent {
    static var title: LocalizedStringResource = "T-Time Wylie to Tibetan"
    static var description = IntentDescription("Convert Wylie (EWTS) transliteration to Tibetan script.")

    @Parameter(title: "Text")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$text) to Tibetan")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: ConvertLogic.convert(text, direction: .toTibetan).text)
    }
}

struct ConvertToWylieIntent: AppIntent {
    static var title: LocalizedStringResource = "T-Time Tibetan to Wylie"
    static var description = IntentDescription("Convert Tibetan script to Wylie (EWTS).")

    @Parameter(title: "Text")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$text) to Wylie")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: ConvertLogic.convert(text, direction: .toWylie).text)
    }
}

struct TTimeToolsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConvertAutoIntent(),
            phrases: ["Auto-convert with \(.applicationName)", "Convert Tibetan with \(.applicationName)"],
            shortTitle: "Auto-convert",
            systemImageName: "arrow.left.arrow.right"
        )
        AppShortcut(
            intent: ConvertToTibetanIntent(),
            phrases: ["Convert to Tibetan with \(.applicationName)"],
            shortTitle: "To Tibetan",
            systemImageName: "character.textbox"
        )
        AppShortcut(
            intent: ConvertToWylieIntent(),
            phrases: ["Convert to Wylie with \(.applicationName)"],
            shortTitle: "To Wylie",
            systemImageName: "textformat.abc"
        )
    }
}
