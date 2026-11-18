import Foundation

/// One entry of the symbol catalogue.
struct SymbolEntry: Equatable {
    let id: String
    let category: String
    let text: String
    let ewts: String?
    let name: String
    let label: String
    let note: String
    let codePoints: String

    /// The text as drawn in a cell: a mark that only exists on a letter gets a
    /// dotted circle to sit on, so it is visible on its own.
    var display: String {
        guard let first = text.unicodeScalars.first else { return text }
        switch first.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return "\u{25CC}" + text
        default: return text
        }
    }
}

/// The symbols window's state and rules, with no UI: the search, the category
/// filter and the selected entry. The catalogue and its search live in the
/// engine (`ttime-core`), so the window offers exactly what the web palette does.
final class SymbolsModel {
    let categories: [String]
    private(set) var query = ""
    private(set) var category: String?  // nil is all categories
    private(set) var results: [SymbolEntry] = []
    private(set) var selected = 0
    private(set) var hint = ""

    init() {
        let cats = take(ttime_symbol_categories_json())
            .flatMap { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String] } ?? []
        categories = cats
        refresh()
    }

    var selectedEntry: SymbolEntry? { results.indices.contains(selected) ? results[selected] : nil }

    func type(_ s: String) {
        query += s
        refresh()
    }

    /// Deletes the last typed character. False if there was nothing to delete.
    @discardableResult
    func backspace() -> Bool {
        guard !query.isEmpty else { return false }
        query.removeLast()
        refresh()
        return true
    }

    func clearQuery() {
        query = ""
        refresh()
    }

    func setCategory(_ c: String?) {
        category = c
        refresh()
    }

    /// Moves to the next category (wrapping through "all"), for the Tab key.
    func nextCategory() {
        guard !categories.isEmpty else { return }
        if let c = category, let i = categories.firstIndex(of: c) {
            category = i + 1 < categories.count ? categories[i + 1] : nil
        } else {
            category = categories[0]
        }
        refresh()
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selected = min(max(selected + delta, 0), results.count - 1)
    }

    func select(_ i: Int) { if results.indices.contains(i) { selected = i } }

    func setHint(_ s: String) { hint = s }

    private func refresh() {
        hint = ""
        selected = 0
        let json = query.withCString { take(ttime_symbols_json($0)) } ?? "[]"
        let items = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: Any]] ?? []
        results = items.compactMap { d in
            guard let id = d["id"] as? String, let cat = d["category"] as? String,
                  let text = d["text"] as? String else { return nil }
            if let c = category, c != cat { return nil }
            return SymbolEntry(id: id, category: cat, text: text, ewts: d["ewts"] as? String,
                               name: d["name"] as? String ?? "", label: d["label"] as? String ?? "",
                               note: d["note"] as? String ?? "", codePoints: d["codePoints"] as? String ?? "")
        }
    }
}
