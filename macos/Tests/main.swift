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
    check(c.handle(.enter), Outcome(insert: "ཀ", marked: "", handled: true), "return commits and is consumed")
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
print(failures == 0 ? "ComposerTests: all passed" : "ComposerTests: \(failures) failed")
exit(failures == 0 ? 0 : 1)
