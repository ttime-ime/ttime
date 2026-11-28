import Foundation

/// The word list behind the Sanskrit (IAST) suggestions, parsed and searched in
/// `ttime-core` (see docs/reference/sanskrit-spike.md). One parsed list is shared by
/// every composer, so giving it to a composer costs nothing.
final class SanskritLexicon {
    let ptr: OpaquePointer?

    /// Parses `word<TAB>count<TAB>flag` lines. The full list takes ~100 ms, so build it
    /// off the main thread (as `shared` does).
    init(data: Data) {
        ptr = data.withUnsafeBytes { raw in
            ttime_lexicon_new(raw.bindMemory(to: UInt8.self).baseAddress, raw.count)
        }
    }

    convenience init(tsv: String) { self.init(data: Data(tsv.utf8)) }

    convenience init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }

    deinit { ttime_lexicon_free(ptr) }

    var count: Int { ttime_lexicon_len(ptr) }

    /// The bundled list, read and parsed once in the background the first time it is
    /// wanted, so typing never waits for it. Nil until it is ready.
    private static var loaded: SanskritLexicon?
    private static var loading = false
    static var shared: SanskritLexicon? {
        if let l = loaded { return l }
        if !loading, let url = Bundle.main.url(forResource: "iast-lexicon", withExtension: "tsv") {
            loading = true
            DispatchQueue.global(qos: .utility).async {
                let l = SanskritLexicon(contentsOf: url)
                DispatchQueue.main.async { loaded = l; loading = false }
            }
        }
        return nil
    }
}
