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
print(failures == 0 ? "ComposerTests: all passed" : "ComposerTests: \(failures) failed")
exit(failures == 0 ? 0 : 1)
