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
    /// dotted circle to sit on, so it is visible on its own (decided in `ttime-core`).
    let display: String
}

/// The symbols window's state and rules, which live in `ttime-core`
/// (`ttime_symbols_model_*`): the search, the category filter and the selected
/// entry. The catalogue is the engine's, so the window offers exactly what the web
/// palette does. This class mirrors the state for the panel after every change.
final class SymbolsModel {
    private let ptr: OpaquePointer?
    private(set) var categories: [String] = []
    private(set) var query = ""
    private(set) var category: String?  // nil is all categories
    private(set) var results: [SymbolEntry] = []
    private(set) var selected = 0
    private(set) var hint = ""

    init() {
        ptr = ttime_symbols_model_new()
        refresh()
    }

    deinit { ttime_symbols_model_free(ptr) }

    var selectedEntry: SymbolEntry? { results.indices.contains(selected) ? results[selected] : nil }

    func type(_ s: String) { change { s.withCString { ttime_symbols_model_type(ptr, $0) } } }

    /// Deletes the last typed character. False if there was nothing to delete.
    @discardableResult
    func backspace() -> Bool { change { ttime_symbols_model_backspace(ptr) } }

    func clearQuery() { change { ttime_symbols_model_clear_query(ptr) } }

    func setCategory(_ c: String?) {
        change {
            if let c = c { c.withCString { ttime_symbols_model_set_category(ptr, $0) } }
            else { ttime_symbols_model_set_category(ptr, nil) }
        }
    }

    /// Moves to the next category (wrapping through "all"), for the Tab key.
    func nextCategory() { change { ttime_symbols_model_next_category(ptr) } }

    func move(_ delta: Int) { change { ttime_symbols_model_move(ptr, Int32(clamping: delta)) } }

    func select(_ i: Int) { change { ttime_symbols_model_select(ptr, Int32(clamping: i)) } }

    func setHint(_ s: String) { change { s.withCString { ttime_symbols_model_set_hint(ptr, $0) } } }

    private func change<T>(_ body: () -> T) -> T {
        let r = body()
        refresh()
        return r
    }

    private func refresh() {
        guard let p = ttime_symbols_model_state_json(ptr) else { return }
        let json = String(cString: p)
        ttime_string_free(p)
        guard let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
        else { return }
        categories = obj["categories"] as? [String] ?? []
        query = obj["query"] as? String ?? ""
        category = obj["category"] as? String
        selected = obj["selected"] as? Int ?? 0
        hint = obj["hint"] as? String ?? ""
        results = (obj["results"] as? [[String: Any]] ?? []).compactMap { d in
            guard let id = d["id"] as? String, let cat = d["category"] as? String,
                  let text = d["text"] as? String else { return nil }
            return SymbolEntry(id: id, category: cat, text: text, ewts: d["ewts"] as? String,
                               name: d["name"] as? String ?? "", label: d["label"] as? String ?? "",
                               note: d["note"] as? String ?? "", codePoints: d["codePoints"] as? String ?? "",
                               display: d["display"] as? String ?? text)
        }
    }
}
