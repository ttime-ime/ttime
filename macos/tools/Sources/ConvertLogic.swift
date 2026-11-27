import Foundation

/// Which way to run the converter.
enum ConvertDirection: String, CaseIterable {
    case auto
    case toTibetan
    case toWylie

    var menuTitle: String {
        switch self {
        case .auto: return "T-Time: Auto-convert"
        case .toTibetan: return "T-Time: Wylie → Tibetan"
        case .toWylie: return "T-Time: Tibetan → Wylie"
        }
    }

    var shortTitle: String {
        switch self {
        case .auto: return "Auto"
        case .toTibetan: return "Wylie → Tibetan"
        case .toWylie: return "Tibetan → Wylie"
        }
    }
}

/// Pure rules for choosing a direction and running a conversion. Easy to test
/// without the engine: pass `toTibetan` / `toWylie` closures.
enum ConvertLogic {
    /// True if the string contains any character in the Tibetan Unicode block.
    static func containsTibetan(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0F00...0x0FFF).contains($0.value) }
    }

    /// Auto: Tibetan script → Wylie; otherwise Wylie/EWTS → Tibetan.
    static func resolved(_ direction: ConvertDirection, text: String) -> ConvertDirection {
        switch direction {
        case .toTibetan, .toWylie: return direction
        case .auto: return containsTibetan(text) ? .toWylie : .toTibetan
        }
    }

    static func convert(
        _ text: String,
        direction: ConvertDirection,
        toTibetan: (String) -> String = { Engine.toTibetan($0) },
        toWylie: (String) -> String = { Engine.toWylie($0) }
    ) -> (text: String, used: ConvertDirection) {
        let used = resolved(direction, text: text)
        let out: String
        switch used {
        case .toTibetan: out = toTibetan(text)
        case .toWylie: out = toWylie(text)
        case .auto: out = text // unreachable: resolved never returns .auto
        }
        return (out, used)
    }
}
