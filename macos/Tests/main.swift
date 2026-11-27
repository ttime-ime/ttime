import Foundation

var failures = 0
func check(_ got: Outcome, _ want: Outcome, _ label: String) {
    if got != want { failures += 1; print("FAIL \(label): got \(got), want \(want)") }
}
func typed(_ c: Composer, _ s: String) -> Outcome {
    var last = Outcome()
    var inserted = ""
    for ch in s {
        last = c.handle(.text(String(ch)))
        inserted += last.insert
    }
    last.insert = inserted
    return last
}

do {
    let c = Composer()
    check(typed(c, "bkra"), Outcome(insert: "", marked: "བཀྲ", handled: true), "provisional text")
    check(c.handle(.text(" ")), Outcome(insert: "བཀྲ་", marked: "", handled: true), "space commits")
}
do {
    let c = Composer()
    _ = typed(c, "kh")
    check(c.handle(.backspace), Outcome(insert: "", marked: "ཀ", handled: true), "backspace edits the run")
    check(c.handle(.backspace), Outcome(insert: "", marked: "", handled: true), "backspace empties the run")
    check(c.handle(.backspace), Outcome(), "backspace with nothing passes through")
}
do {
    let c = Composer()
    check(c.handle(.escape), Outcome(), "escape with nothing passes through")
    _ = typed(c, "ka")
    check(c.handle(.escape), Outcome(handled: true), "escape cancels")
    check(c.handle(.enter), Outcome(), "return with nothing passes through")
}
do {
    let c = Composer()
    _ = typed(c, "ka")
    check(c.handle(.enter), Outcome(insert: "ཀ", marked: "", handled: false), "return commits then passes to the app")
}
do {
    let c = Composer()
    _ = typed(c, "ka")
    check(c.handle(.other), Outcome(insert: "ཀ", marked: "", handled: false), "arrow commits then passes")
    check(c.handle(.other), Outcome(), "arrow with nothing pending passes")
}
do {
    let c = Composer()
    _ = typed(c, "[a b")
    let o = c.handle(.text(" "))
    if o.insert != "" || !o.handled { failures += 1; print("FAIL space inside brackets stays provisional: \(o)") }
}
do {
    let c = Composer()
    var all = ""
    for word in ["bkra", "shis", "bde", "legs"] { all += typed(c, word + " ").insert }
    check(Outcome(insert: all), Outcome(insert: "བཀྲ་ཤིས་བདེ་ལེགས་"), "four syllables")
}
do {
    let c = Composer()
    _ = typed(c, "ka")
    c.reset()
    check(c.handle(.enter), Outcome(), "reset forgets pending input")
}

// --- Latin mode ---
do {
    let c = Composer()
    _ = typed(c, "ka")
    check(c.setLatin(true), Outcome(insert: "ཀ", marked: "", handled: true), "going Latin fixes the pending run")
    if !c.isLatin { failures += 1; print("FAIL isLatin after setLatin(true)") }
    check(typed(c, "ka "), Outcome(insert: "ka ", marked: "", handled: true), "Latin passes text through")
    check(c.setLatin(false), Outcome(handled: true), "back to Tibetan with nothing pending")
    check(typed(c, "ka "), Outcome(insert: "ཀ་", marked: "", handled: true), "Tibetan again")
}

// --- Shift taps ---
let L = ShiftTap.leftKeyCode, R = ShiftTap.rightKeyCode
let lBit = ShiftTap.leftShiftBit, rBit = ShiftTap.rightShiftBit
func tap(_ t: inout ShiftTap, _ code: UInt16, _ bit: UInt, at time: Double, hold: Double = 0.1) -> ShiftTapEvent? {
    _ = t.flagsChanged(keyCode: code, flags: bit, time: time)
    return t.flagsChanged(keyCode: code, flags: 0, time: time + hold)
}
func expect(_ got: ShiftTapEvent?, _ want: ShiftTapEvent?, _ label: String) {
    if got != want { failures += 1; print("FAIL \(label): got \(String(describing: got)), want \(String(describing: want))") }
}
do {
    var t = ShiftTap()
    expect(tap(&t, L, lBit, at: 0), ShiftTapEvent(side: .left, kind: .single), "left tap")
    expect(tap(&t, R, rBit, at: 5), ShiftTapEvent(side: .right, kind: .single), "right tap")
}
do {
    var t = ShiftTap()
    _ = t.flagsChanged(keyCode: L, flags: lBit, time: 0)
    t.keyDown()
    expect(t.flagsChanged(keyCode: L, flags: 0, time: 0.1), nil, "Shift+letter is not a tap")
    expect(tap(&t, L, lBit, at: 1), ShiftTapEvent(side: .left, kind: .single), "tap after a chord works")
}
do {
    var t = ShiftTap()
    _ = t.flagsChanged(keyCode: L, flags: lBit | ShiftTap.commandBit, time: 0)
    expect(t.flagsChanged(keyCode: L, flags: 0, time: 0.1), nil, "Shift+Command is not a tap")
    _ = t.flagsChanged(keyCode: L, flags: lBit, time: 1)
    _ = t.flagsChanged(keyCode: 59, flags: lBit | ShiftTap.controlBit, time: 1.05)  // Control joins
    _ = t.flagsChanged(keyCode: 59, flags: lBit, time: 1.1)
    expect(t.flagsChanged(keyCode: L, flags: 0, time: 1.2), nil, "Control touched while held spoils the tap")
}
do {
    var t = ShiftTap()
    expect(tap(&t, L, lBit, at: 0, hold: 0.6), nil, "a long press is not a tap")
}
do {
    var t = ShiftTap()
    _ = t.flagsChanged(keyCode: L, flags: lBit, time: 0)
    _ = t.flagsChanged(keyCode: R, flags: lBit | rBit, time: 0.05)
    expect(t.flagsChanged(keyCode: L, flags: rBit, time: 0.1), nil, "both Shifts: left release is no tap")
    expect(t.flagsChanged(keyCode: R, flags: 0, time: 0.12), nil, "both Shifts: right release is no tap")
}
do {
    var t = ShiftTap()
    expect(tap(&t, L, lBit, at: 0), ShiftTapEvent(side: .left, kind: .single), "first tap of a pair")
    expect(tap(&t, L, lBit, at: 0.3), ShiftTapEvent(side: .left, kind: .double), "second tap is a double")
    expect(tap(&t, L, lBit, at: 0.6), ShiftTapEvent(side: .left, kind: .single), "third tap starts a new pair")
}
do {
    var t = ShiftTap()
    _ = tap(&t, L, lBit, at: 0)
    expect(tap(&t, L, lBit, at: 0.9), ShiftTapEvent(side: .left, kind: .single), "taps too far apart are two singles")
}
do {
    var t = ShiftTap()
    _ = tap(&t, R, rBit, at: 0)
    expect(tap(&t, L, lBit, at: 0.2), ShiftTapEvent(side: .left, kind: .single), "left does not pair with right")
    expect(tap(&t, R, rBit, at: 0.4), ShiftTapEvent(side: .right, kind: .double), "pairing is per side")
}
do {
    var t = ShiftTap()
    _ = tap(&t, L, lBit, at: 0)
    t.keyDown()
    expect(tap(&t, L, lBit, at: 0.3), ShiftTapEvent(side: .left, kind: .single), "a key between taps breaks the pair")
}
do {
    var t = ShiftTap()
    _ = t.flagsChanged(keyCode: L, flags: lBit, time: 0)
    t.reset()
    expect(t.flagsChanged(keyCode: L, flags: 0, time: 0.1), nil, "reset forgets a held Shift")
}

// --- Mode lock ---
do {
    var m = ModeLock()
    if m.leftTap(.single, isLatin: false) != true { failures += 1; print("FAIL single tap flips to Latin") }
    if m.leftTap(.single, isLatin: true) != false { failures += 1; print("FAIL single tap flips back") }
}
do {
    var m = ModeLock()
    // First tap flipped Tibetan to Latin; the second tap of the pair arrives.
    if m.leftTap(.double, isLatin: true) != false || m.lockedLatin != false {
        failures += 1; print("FAIL double tap undoes the flip and locks Tibetan: \(m)")
    }
    if m.leftTap(.single, isLatin: false) != nil { failures += 1; print("FAIL single tap is ignored while locked") }
    if !(m.modeOnFocus == false) { failures += 1; print("FAIL locked Tibetan on focus") }
    if m.leftTap(.double, isLatin: false) != nil || m.lockedLatin != nil {
        failures += 1; print("FAIL double tap unlocks and leaves the mode: \(m)")
    }
}
do {
    var m = ModeLock()
    // Latin, then a pair: first tap flipped Latin to Tibetan.
    if m.leftTap(.double, isLatin: false) != true || m.lockedLatin != true { failures += 1; print("FAIL lock Latin") }
    if m.modeOnFocus != true { failures += 1; print("FAIL locked Latin survives focus") }
    if ModeLock().modeOnFocus != false { failures += 1; print("FAIL unlocked focus starts Tibetan") }
}
do {
    var m = ModeLock()
    if m.choose(latin: true) != true || m.choose(latin: false) != false { failures += 1; print("FAIL toolbar click picks a mode") }
    m.toggleLock(isLatin: true)
    if m.lockedLatin != true { failures += 1; print("FAIL toolbar lock locks the current mode") }
    if m.choose(latin: false) != false || m.lockedLatin != false { failures += 1; print("FAIL toolbar click works while locked and the lock follows it") }
    if m.leftTap(.single, isLatin: false) != nil { failures += 1; print("FAIL Shift taps stay ignored after the toolbar changed a locked mode") }
    m.toggleLock(isLatin: false)
    if m.choose(latin: true) != true || m.lockedLatin != nil { failures += 1; print("FAIL toolbar click leaves an unlocked mode unlocked") }
    m.toggleLock(isLatin: true)
    m.toggleLock(isLatin: true)
    if m.lockedLatin != nil { failures += 1; print("FAIL toolbar lock button unlocks") }
}
do {
    let m = StackerModel()
    if m.result != .empty { failures += 1; print("FAIL stacker starts empty") }
    for k in ["r", "g", "y"] { m.addLayer(k) }
    guard let b = m.built else { failures += 1; print("FAIL rgya builds: \(m.result)"); exit(1) }
    if b.text != "རྒྱ" || b.shortest != "rgya" || b.canonical != "r+g+ya" || b.codePoints != "0F62 0F92 0FB1" {
        failures += 1; print("FAIL rgya answer: \(b)")
    }
    m.setVowel("i")
    if m.built?.shortest != "rgyi" { failures += 1; print("FAIL vowel: \(m.result)") }
    m.setVowel("i")
    if m.built?.shortest != "rgya" { failures += 1; print("FAIL vowel toggles off") }
    m.toggleMark("M")
    if m.built?.shortest.hasSuffix("M") != true { failures += 1; print("FAIL mark: \(m.result)") }
    m.backspace()
    if m.layers != ["r", "g"] { failures += 1; print("FAIL backspace removes the last letter: \(m.layers)") }
    let inserted = m.consume()
    if inserted == nil || m.layers != [] || m.result != .empty || !m.hint.hasPrefix("Inserted") {
        failures += 1; print("FAIL consume starts over: \(m.layers) \(m.hint)")
    }
}
do {
    let m = StackerModel()
    // Typing: exact match wins, otherwise the only candidate, and the grid narrows.
    m.type("k")
    if m.typedKey != "k" || !m.matches("kh") || m.matches("g") { failures += 1; print("FAIL typing k") }
    m.type("h")
    if m.typedKey != "kh" || m.matches("k") { failures += 1; print("FAIL typing kh") }
    m.confirmTyped()
    if m.layers != ["kh"] || m.typed != "" { failures += 1; print("FAIL confirm adds the letter") }
    m.type("q")
    if m.confirmTyped() || m.hint.isEmpty { failures += 1; print("FAIL unknown letter explains itself") }
    m.backspace()
    m.backspace()
    if m.layers != [] { failures += 1; print("FAIL backspace after typed text: \(m.layers)") }
    if m.addLayer("W") || !m.layers.isEmpty || m.hint.isEmpty { failures += 1; print("FAIL W needs a letter above") }
    if m.backspace() { failures += 1; print("FAIL backspace with nothing passes through") }
    m.usePreset(["W", "k"])
    if case .failed = m.result {} else { failures += 1; print("FAIL engine refuses W on top: \(m.result)") }
    m.usePreset(["k", "Sh"])
    if m.built?.text != "ཀྵ" { failures += 1; print("FAIL preset kSha: \(m.result)") }
    if m.alphabet.consonants.count < 30 || m.alphabet.vowels.isEmpty || m.alphabet.marks.isEmpty {
        failures += 1; print("FAIL alphabet is loaded")
    }
}
do {
    let m = SymbolsModel()
    if m.results.count < 50 || m.categories.count < 5 { failures += 1; print("FAIL catalogue loads: \(m.results.count)") }
    m.type("shad")
    if !m.results.contains(where: { $0.id == "shad" && $0.text == "།" }) { failures += 1; print("FAIL search finds shad") }
    m.clearQuery()
    m.setCategory("punctuation")
    if m.results.isEmpty || m.results.contains(where: { $0.category != "punctuation" }) { failures += 1; print("FAIL category filter") }
    m.setCategory(nil)
    for _ in 0...m.categories.count { m.nextCategory() }
    if m.category != nil { failures += 1; print("FAIL Tab cycles back to all: \(String(describing: m.category))") }
    m.move(2)
    if m.selected != 2 { failures += 1; print("FAIL move selects") }
    m.move(-9)
    if m.selected != 0 { failures += 1; print("FAIL move stops at the top") }
    m.type("zzzzzz")
    if !m.results.isEmpty || m.selectedEntry != nil { failures += 1; print("FAIL no match") }
    if !m.backspace() { failures += 1; print("FAIL backspace edits the search") }
    m.clearQuery()
    if m.backspace() { failures += 1; print("FAIL backspace with an empty search passes through") }
    let mark = SymbolEntry(id: "x", category: "marks", text: "\u{0F7E}", ewts: "M", name: "", label: "", note: "", codePoints: "")
    if mark.display != "\u{25CC}\u{0F7E}" { failures += 1; print("FAIL combining mark gets a base") }
}
do {
    // What macOS really sends an input method: only the generic Shift bit (0x20000),
    // no per-key device bits (seen in a log from a real run).
    let sh = ShiftTap.shiftMask
    var t = ShiftTap()
    expect(tap(&t, L, sh, at: 0), ShiftTapEvent(side: .left, kind: .single), "generic bits: left tap")
    expect(tap(&t, L, sh, at: 0.3), ShiftTapEvent(side: .left, kind: .double), "generic bits: left double")
    expect(tap(&t, R, sh, at: 5), ShiftTapEvent(side: .right, kind: .single), "generic bits: right tap")
    expect(tap(&t, R, sh, at: 5.2), ShiftTapEvent(side: .right, kind: .double), "generic bits: right double")
    var c = ShiftTap()
    _ = c.flagsChanged(keyCode: L, flags: sh, time: 0)
    c.keyDown()
    expect(c.flagsChanged(keyCode: L, flags: 0, time: 0.1), nil, "generic bits: Shift+letter is not a tap")
    var b = ShiftTap()
    _ = b.flagsChanged(keyCode: L, flags: sh, time: 0)
    _ = b.flagsChanged(keyCode: R, flags: sh, time: 0.05)
    expect(b.flagsChanged(keyCode: L, flags: sh, time: 0.1), nil, "generic bits: both Shifts, left release")
    expect(b.flagsChanged(keyCode: R, flags: 0, time: 0.12), nil, "generic bits: both Shifts, right release")
    expect(tap(&b, L, sh, at: 3), ShiftTapEvent(side: .left, kind: .single), "generic bits: tap after both Shifts")
    var m = ShiftTap()
    _ = m.flagsChanged(keyCode: L, flags: sh | ShiftTap.commandBit, time: 0)
    expect(m.flagsChanged(keyCode: L, flags: 0, time: 0.1), nil, "generic bits: Shift+Command is not a tap")
}

// Updater
do {
    func v(_ s: String) -> AppVersion { AppVersion(s)! }
    func t(_ ok: Bool, _ label: String) { if !ok { failures += 1; print("FAIL \(label)") } }
    t(v("0.1.0-rc.1") < v("0.1.0-rc.2"), "rc order")
    t(v("0.1.0-rc.2") < v("0.1.0"), "rc before release")
    t(v("0.1.0") < v("0.1.1"), "patch")
    t(v("v0.2") > v("0.1.9"), "v prefix and short")
    t(v("0.1.0-rc.9") < v("0.1.0-rc.10"), "numeric pre identifiers")
    t(AppVersion("junk") == nil, "junk")

    let json = """
    [{"tag_name":"v0.1.0","html_url":"u","prerelease":false,"draft":false,"assets":[
      {"name":"T-Time-0.1.0-UNSIGNED.pkg","browser_download_url":"a"},
      {"name":"T-Time-0.1.0.pkg","browser_download_url":"b","digest":"sha256:ABC"}]},
     {"tag_name":"v0.2.0-rc.1","html_url":"u2","prerelease":true,"draft":false,"assets":[]},
     {"tag_name":"v9.9.9","html_url":"d","prerelease":false,"draft":true,"assets":[]}]
    """
    let rs = Updater.parse(Data(json.utf8))
    t(rs.count == 3, "parse count")
    t(Updater.newest(in: rs, than: "0.1.0-rc.2")?.tag == "v0.2.0-rc.1", "prerelease build follows prereleases")
    t(Updater.newest(in: rs, than: "0.0.9")?.tag == "v0.1.0", "final build skips prereleases and drafts")
    t(Updater.newest(in: rs, than: "0.1.0") == nil, "up to date")
    t(Updater.newest(in: rs, than: "0.1.0", includePrereleases: true)?.tag == "v0.2.0-rc.1", "opt in to release candidates")
    let asset = Updater.installer(of: rs[0])
    t(asset?.url == "b" && asset?.sha256 == "abc", "installer asset and digest")
    let now = Date()
    t(Updater.checkDue(last: nil, now: now), "first check due")
    t(!Updater.checkDue(last: now.addingTimeInterval(-3600), now: now), "check not due within 6h")
    t(Updater.checkDue(last: now.addingTimeInterval(-7 * 3600), now: now), "check due after 6h")
    t(!Updater.offerDue(lastTag: "v1", lastOffered: now.addingTimeInterval(-3600), tag: "v1", now: now), "same release not re-offered within a day")
    t(Updater.offerDue(lastTag: "v1", lastOffered: now.addingTimeInterval(-3600), tag: "v2", now: now), "newer release offered at once")
}

// Sanskrit suggestions
do {
    func t(_ ok: Bool, _ label: String) { if !ok { failures += 1; print("FAIL \(label)") } }
    let tsv = "prajñā\t100\tb\nprajña\t10\t-\nprājña\t5\t-\npratītyasamutpāda\t20\tb\npratyaya\t50\tb\nśiva\t80\t-\nśivā\t3\t-\nsiva\t1\t-\nśūnyatā\t40\tb\n"
    let lex = SanskritLexicon(tsv: tsv)
    t(SanskritLexicon.fold("śūnyatā") == "sunyata", "fold")
    t(lex.suggest("praj") == ["prajñā", "prajña", "prājña"], "prefix ranked by count: \(lex.suggest("praj"))")
    t(lex.suggest("siva") == ["śiva", "śivā", "siva"], "ambiguous key ranked: \(lex.suggest("siva"))")
    t(lex.suggest("pra").first == "prajñā" && lex.suggest("pra").count == 5, "limit five")
    t(lex.suggest("zzz").isEmpty, "no match")
    t(lex.suggest("Sunya") == ["śūnyatā"], "capitals and accents ignored")

    func latin() -> Composer {
        let c = Composer()
        _ = c.setLatin(true)
        c.suggester = SanskritSuggester(lexicon: lex)
        return c
    }
    func type(_ c: Composer, _ s: String) -> Outcome { var o = Outcome(); for ch in s { o = c.handle(.text(String(ch))) }; return o }
    do {
        let c = latin()
        check(type(c, "pr"), Outcome(insert: "r", marked: "", handled: true), "letters go straight into the document (no marked text)")
        t(c.suggestionList == nil, "no list under three letters")
        _ = type(c, "aj")
        t(c.suggestionList?.words.first == "prajñā", "list shows")
        check(c.handle(.tab), Outcome(insert: "prajñā", replacing: "praj", handled: true), "tab replaces the typed word")
        t(c.suggestionList == nil, "list gone after accepting")
    }
    do {
        let c = latin(); _ = type(c, "praj")
        check(c.handle(.down), Outcome(handled: true), "down moves")
        t(c.suggestionList?.selected == 1, "second selected")
        check(c.handle(.tab), Outcome(insert: "prajña", replacing: "praj", handled: true), "tab accepts the selected one")
    }
    do {
        let c = latin(); _ = type(c, "siva")
        check(c.handle(.text(" ")), Outcome(insert: " ", handled: true), "space keeps what was typed (it is already there)")
    }
    do {
        let c = latin(); _ = type(c, "Praj")
        check(c.handle(.tab), Outcome(insert: "Prajñā", replacing: "Praj", handled: true), "capital kept")
    }
    do {
        let c = latin(); _ = type(c, "praj")
        check(c.handle(.backspace), Outcome(handled: false), "backspace is left to the application, the copy follows")
        t(c.suggestionBuffer == "pra", "the copy lost a letter")
        check(c.handle(.escape), Outcome(handled: true), "escape keeps the typed text")
    }
    do {
        let c = latin(); _ = type(c, "pr")
        check(c.handle(.tab), Outcome(handled: false), "tab with no list passes through")
        _ = type(c, "praj")
        check(c.handle(.enter), Outcome(handled: false), "return passes through")
        _ = type(c, "praj")
        check(c.handle(.text("1")), Outcome(insert: "1", handled: true), "digit ends the word")
        _ = type(c, "praj")
        check(c.setLatin(false), Outcome(handled: true), "leaving Latin forgets the word, which is already typed")
    }
    do {
        let c = latin()
        check(c.handle(.tab), Outcome(), "tab with no word is not ours")
        let off = Composer(); _ = off.setLatin(true)
        check(type(off, "a"), Outcome(insert: "a", marked: "", handled: true), "off: typed text passes straight through")
    }
}

// Long-press accent palette
do {
    func t(_ ok: Bool, _ label: String) { if !ok { failures += 1; print("FAIL \(label)") } }
    for (k, vs) in AccentPalette.lower {
        for v in vs { t(v.precomposedStringWithCanonicalMapping == v && v.unicodeScalars.count == 1, "NFC single scalar \(k)->\(v)") }
    }
    t(AccentPalette.variants(for: "S") == ["Ś", "Ṣ"], "capitals give capitals")
    t(AccentPalette.variants(for: "k").isEmpty && AccentPalette.variants(for: "ab").isEmpty, "no variants")

    let lex = SanskritLexicon(tsv: "prajñā\t100\tb\nprajña\t10\t-\nsūtra\t30\tb\n")
    func latin(suggest: Bool) -> Composer {
        let c = Composer()
        _ = c.setLatin(true)
        c.accents = true
        if suggest { c.suggester = SanskritSuggester(lexicon: lex) }
        return c
    }
    func type(_ c: Composer, _ s: String) { for ch in s { _ = c.handle(.text(String(ch))) } }
    let hold: (Composer, String) -> Outcome = { c, s in c.handle(.text(s), isRepeat: true) }

    // With suggestions: the letter is in the word, the palette replaces it.
    do {
        let c = latin(suggest: true); type(c, "pr")
        type(c, "a")
        check(hold(c, "a"), Outcome(handled: true), "first repeat opens the palette")
        t(c.accentList?.options == ["ā"] && c.accentList?.selected == nil, "palette lists the variants")
        check(hold(c, "a"), Outcome(handled: true), "further repeats are swallowed")
        check(c.handle(.text("1")), Outcome(insert: "ā", replacing: "a", handled: true), "number picks")
        t(c.accentList == nil, "palette closed after a pick")
        t(c.handle(.text("j")).insert == "j" && c.suggestionBuffer == "prāj", "typing goes on after the accent")
    }
    do {
        let c = latin(suggest: true); type(c, "pr")
        _ = hold(c, "r")
        t(c.accentList?.options == ["ṛ", "ṝ"], "r has two variants")
        _ = c.handle(.right)
        _ = c.handle(.right)
        t(c.accentList?.selected == 1, "arrows move the highlight")
        check(c.handle(.enter), Outcome(insert: "ṝ", replacing: "r", handled: true), "return picks the highlighted variant")
    }
    do {
        let c = latin(suggest: true); type(c, "pn")
        _ = hold(c, "n")
        t(c.accentList?.options.count == 3, "n has three variants")
        _ = c.handle(.tab); t(c.accentList?.selected == 0, "tab highlights the first")
        _ = c.handle(.tab); _ = c.handle(.tab); t(c.accentList?.selected == 2, "tab goes on")
        _ = c.handle(.tab); t(c.accentList?.selected == 0, "tab wraps round")
        check(c.handle(.text(" ")), Outcome(insert: "ṅ", replacing: "n", handled: true), "space picks the highlighted variant")
    }
    do {
        let c = latin(suggest: true); type(c, "pra")
        _ = hold(c, "a")
        check(c.handle(.escape), Outcome(handled: true), "escape closes and keeps the plain letter")
        t(c.accentList == nil, "closed by escape")
        _ = hold(c, "a")
        let o = c.handle(.text("j"))
        t(o.insert == "j" && c.suggestionBuffer == "praj" && c.accentList == nil, "another key keeps the plain letter and types")
        type(c, "a"); _ = hold(c, "a")
        let b = c.handle(.backspace)
        t(!b.handled && c.suggestionBuffer == "praj" && c.accentList == nil, "backspace closes the palette and edits")
    }
    do {
        let c = latin(suggest: true); type(c, "pra")
        _ = hold(c, "a")
        check(c.handle(.enter), Outcome(handled: false), "return with nothing highlighted keeps the letter and passes through")
        type(c, "a"); _ = hold(c, "a")
        check(c.handle(.text(" ")), Outcome(insert: " ", handled: true), "space with nothing highlighted ends the word")
    }
    do {
        let c = latin(suggest: true); type(c, "ak")
        check(hold(c, "k"), Outcome(insert: "k", handled: true), "a letter without variants repeats as usual")
        t(c.accentList == nil, "no palette for k")
    }
    do {
        let c = latin(suggest: true); type(c, "pra")
        t(hold(c, "u").insert == "u" && c.suggestionBuffer == "prau", "repeat of a letter that is not the last typed is plain typing")
    }
    // Without suggestions: the letter waits as marked text.
    do {
        let c = latin(suggest: false)
        check(c.handle(.text("a")), Outcome(insert: "", marked: "a", handled: true), "variant letter waits")
        check(c.handle(.text("k")), Outcome(insert: "ak", marked: "", handled: true), "next key commits it")
        check(c.handle(.text("a")), Outcome(insert: "", marked: "a", handled: true), "waits again")
        check(c.handle(.text("i")), Outcome(insert: "a", marked: "i", handled: true), "next variant letter commits the previous one")
        check(hold(c, "i"), Outcome(insert: "", marked: "i", handled: true), "repeat opens")
        check(c.handle(.text("1")), Outcome(insert: "ī", marked: "", handled: true), "pick commits the variant")
        t(c.commitAll().isEmpty, "nothing left over")
    }
    do {
        let c = latin(suggest: false); _ = c.handle(.text("s"))
        check(c.handle(.backspace), Outcome(insert: "", marked: "", handled: true), "backspace removes the waiting letter")
        _ = c.handle(.text("s"))
        check(c.handle(.enter), Outcome(insert: "s", marked: "", handled: false), "return commits it and passes through")
        _ = c.handle(.text("s"))
        t(c.commitAll() == "s", "commitAll includes the waiting letter")
        _ = c.handle(.text("s"))
        check(c.setLatin(false), Outcome(insert: "s", marked: "", handled: true), "leaving Latin commits it")
    }
    do {
        let c = latin(suggest: false); _ = c.handle(.text("s"))
        c.reset()
        t(c.commitAll().isEmpty, "reset forgets the waiting letter")
    }
    // Off, or in Tibetan mode: untouched.
    do {
        let c = Composer(); _ = c.setLatin(true)
        check(c.handle(.text("a")), Outcome(insert: "a", marked: "", handled: true), "off: plain")
        let tib = Composer(); tib.accents = true
        t(tib.handle(.text("a"), isRepeat: true).handled && tib.accentList == nil, "Tibetan mode has no palette")
    }
    // Clicking a variant.
    do {
        let c = latin(suggest: true); type(c, "pra")
        check(c.chooseAccent(index: 0), Outcome(), "click on a closed palette does nothing")
        _ = hold(c, "a")
        check(c.chooseAccent(index: 0), Outcome(insert: "ā", replacing: "a", handled: true), "click picks")
        // The key is still held while the variant is clicked: its repeats must not type.
        check(hold(c, "a"), Outcome(handled: true), "repeats of the held key are ignored after a click")
        check(hold(c, "a"), Outcome(handled: true), "and keep being ignored")
        t(c.accentList == nil, "and do not reopen the palette")
        t(c.handle(.text("a")).insert == "a" && c.suggestionBuffer == "prāa", "a fresh press types again")
    }
    do {
        let c = latin(suggest: false); _ = c.handle(.text("a")); _ = hold(c, "a")
        check(c.chooseAccent(index: 0), Outcome(insert: "ā", marked: "", handled: true), "click picks with no suggester")
        check(hold(c, "a"), Outcome(insert: "", marked: "", handled: true), "repeats ignored, nothing typed")
        check(c.handle(.text("k")), Outcome(insert: "k", marked: "", handled: true), "typing goes on")
    }
    do {
        let c = latin(suggest: true); type(c, "pn")
        check(c.chooseHighlightedAccent(), Outcome(), "nothing highlighted: nothing happens")
        _ = hold(c, "n")
        check(c.chooseHighlightedAccent(), Outcome(), "open but nothing highlighted: nothing happens")
        _ = c.handle(.tab); _ = c.handle(.tab)
        check(c.chooseHighlightedAccent(), Outcome(insert: "ñ", replacing: "n", handled: true), "letting go picks the highlighted variant")
        t(c.accentList == nil, "closed after release")
    }
    do {
        let c = latin(suggest: true); type(c, "pa")
        _ = hold(c, "a")
        _ = c.handle(.escape)
        check(hold(c, "a"), Outcome(handled: true), "escape while still held: no reopening, no typing")
        t(c.accentList == nil, "palette stays closed")
    }
    do {
        let c = latin(suggest: true)
        check(c.chooseSuggestion(index: 0), Outcome(), "click with no list does nothing")
        type(c, "praj")
        check(c.chooseSuggestion(index: 1), Outcome(insert: "prajña", replacing: "praj", handled: true), "click accepts that suggestion")
        t(c.suggestionList == nil, "list gone after a click")
    }
}

do {
    func eq(_ got: String, _ want: String, _ label: String) {
        if got != want { failures += 1; print("FAIL \(label): got \(got.debugDescription), want \(want.debugDescription)") }
    }
    eq(DictionaryLookup.term(selection: nil, before: "བོད་སྐད་"), "སྐད", "syllable before the caret, tsheg dropped")
    eq(DictionaryLookup.term(selection: nil, before: "བོད་སྐད"), "སྐད", "no trailing tsheg")
    eq(DictionaryLookup.term(selection: nil, before: "བོད་སྐད། "), "སྐད", "shad and space dropped")
    eq(DictionaryLookup.term(selection: nil, before: "hello"), "", "Latin before the caret gives nothing")
    eq(DictionaryLookup.term(selection: "བོད་སྐད་", before: "x"), "བོད་སྐད", "selection wins, trailing tsheg trimmed")
    eq(DictionaryLookup.term(selection: "  ", before: "བོད་"), "བོད", "blank selection falls back to the caret")
    eq(DictionaryLookup.term(selection: nil, before: nil), "", "nothing")
    eq(DictionaryLookup.url(for: "སྐད")?.absoluteString ?? "",
       "https://dictionary.christian-steinert.de/#/search/tib/%E0%BD%A6%E0%BE%90%E0%BD%91?activeTerm=%E0%BD%A6%E0%BE%90%E0%BD%91",
       "search URL")
    eq(DictionaryLookup.url(for: "a b&c#")?.absoluteString ?? "",
       "https://dictionary.christian-steinert.de/#/search/tib/a%20b%26c%23?activeTerm=a%20b%26c%23", "URL escapes reserved characters")
    eq(DictionaryLookup.url(for: "  ")?.absoluteString ?? "none", "none", "blank term has no URL")
}

print(failures == 0 ? "ComposerTests: all passed" : "ComposerTests: \(failures) failed")
exit(failures == 0 ? 0 : 1)
