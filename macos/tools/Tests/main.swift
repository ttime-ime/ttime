import Foundation

var failed = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String) {
    if cond() { return }
    failed += 1
    fputs("FAIL: \(msg)\n", stderr)
}

// Direction detection (no engine).
check(!ConvertLogic.containsTibetan("bkra shis"), "ASCII is not Tibetan")
check(ConvertLogic.containsTibetan("བཀྲ་ཤིས"), "Tibetan block detected")
check(ConvertLogic.containsTibetan("hello བ"), "mixed text counts as Tibetan")

check(ConvertLogic.resolved(.auto, text: "bkra") == .toTibetan, "auto Latin → Tibetan")
check(ConvertLogic.resolved(.auto, text: "བཀྲ") == .toWylie, "auto Tibetan → Wylie")
check(ConvertLogic.resolved(.toWylie, text: "bkra") == .toWylie, "explicit direction wins")

let stubTib: (String) -> String = { "T:\($0)" }
let stubWylie: (String) -> String = { "W:\($0)" }
let a = ConvertLogic.convert("bkra", direction: .auto, toTibetan: stubTib, toWylie: stubWylie)
check(a.text == "T:bkra" && a.used == .toTibetan, "auto convert Latin")
let b = ConvertLogic.convert("བ", direction: .auto, toTibetan: stubTib, toWylie: stubWylie)
check(b.text == "W:བ" && b.used == .toWylie, "auto convert Tibetan")
let c = ConvertLogic.convert("བ", direction: .toTibetan, toTibetan: stubTib, toWylie: stubWylie)
check(c.text == "T:བ" && c.used == .toTibetan, "forced to Tibetan")

// Engine round-trip (needs linked libttime_ffi).
let tib = Engine.toTibetan("bkra shis")
check(tib == "བཀྲ་ཤིས", "EWTS → Tibetan: got \(tib)")
let back = Engine.toWylie(tib)
check(back == "bkra shis", "Tibetan → EWTS: got \(back)")
check(Engine.toTibetan("") == "", "empty convert")
check(Engine.toWylie("") == "", "empty reverse")
check(!Engine.version.isEmpty, "engine version")

if failed > 0 {
    fputs("\(failed) test(s) failed\n", stderr)
    exit(1)
}
print("ok")
