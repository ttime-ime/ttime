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
    if m.choose(latin: false) != nil { failures += 1; print("FAIL toolbar click is refused while locked") }
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

print(failures == 0 ? "ComposerTests: all passed" : "ComposerTests: \(failures) failed")
exit(failures == 0 ? 0 : 1)
