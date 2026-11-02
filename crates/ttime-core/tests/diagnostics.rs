//! Every diagnostic code has at least one test here, and spans are checked as
//! UTF-8 byte offsets.

use std::collections::HashSet;

use ttime_core::{convert, ewts_to_unicode, Category, Code, Options, Severity};

/// (code, the input text the span covers)
fn found(input: &str) -> Vec<(Code, &str)> {
    convert(input, Options::default())
        .diagnostics
        .into_iter()
        .map(|d| (d.code, &input[d.span]))
        .collect()
}

fn codes(input: &str) -> Vec<Code> {
    found(input).into_iter().map(|(c, _)| c).collect()
}

#[test]
fn well_formed_input_has_no_diagnostics() {
    for input in [
        "bsgrubs",
        "bod skad",
        "rgyal po",
        "bkra shis bde legs",
        "k+Sha",
        "0123",
        "/",
        "[free text]",
        "g.ya",
    ] {
        assert_eq!(found(input), vec![], "{input:?}");
    }
}

#[test]
fn dangling_plus_is_incomplete() {
    assert_eq!(found("k+"), vec![(Code::DanglingPlus, "+")]);
    assert_eq!(convert("k+", Options::default()).text, "ཀ+");
}

#[test]
fn stray_plus_is_invalid() {
    assert_eq!(found("k+ g"), vec![(Code::StrayPlus, "+")]);
    assert_eq!(found("+ka"), vec![(Code::StrayPlus, "+")]);
    assert_eq!(
        found("k++a"),
        vec![(Code::StrayPlus, "+"), (Code::StrayPlus, "+")]
    );
    assert_eq!(ewts_to_unicode("+ka"), "+ཀ");
}

#[test]
fn plus_after_explicit_a_continues_the_stack() {
    assert_eq!(found("ka+ya"), vec![]);
    assert_eq!(ewts_to_unicode("ka+ya"), "ཀྱ");
    assert_eq!(ewts_to_unicode("ya+ya"), "ཡྱ");
}

#[test]
fn mark_without_base() {
    assert_eq!(found("M"), vec![(Code::MarkWithoutBase, "M")]);
    assert_eq!(found("~M"), vec![(Code::MarkWithoutBase, "~M")]);
    assert_eq!(found("ka M"), vec![(Code::MarkWithoutBase, "M")]);
}

#[test]
fn duplicate_mark_keeps_both() {
    let c = convert("kMM", Options::default());
    assert_eq!(c.diagnostics.len(), 1);
    assert_eq!(c.diagnostics[0].code, Code::DuplicateMark);
    assert_eq!(c.diagnostics[0].span, 2..3);
    assert_eq!(c.text, "ཀ\u{0F7E}\u{0F7E}");
}

#[test]
fn unsupported_character() {
    assert_eq!(found("kaq"), vec![(Code::UnsupportedCharacter, "q")]);
    assert_eq!(found("K"), vec![(Code::UnsupportedCharacter, "K")]);
    assert_eq!(ewts_to_unicode("kaq"), "ཀq");
    // Other scripts and punctuation are not EWTS errors.
    assert_eq!(found("ka é 中 ,"), vec![]);
}

#[test]
fn tilde() {
    assert_eq!(found("ka~g"), vec![(Code::StrayTilde, "~")]);
    assert_eq!(found("ka~"), vec![(Code::IncompleteTilde, "~")]);
    assert_eq!(found("k~M"), vec![]);
    assert_eq!(found("k~X"), vec![]);
}

#[test]
fn unterminated_literal() {
    assert_eq!(found("ka [abc"), vec![(Code::UnterminatedLiteral, "[abc")]);
    assert_eq!(ewts_to_unicode("ka [abc"), "ཀ་abc");
}

#[test]
fn escapes() {
    assert_eq!(found("ka\\"), vec![(Code::IncompleteEscape, "\\")]);
    assert_eq!(found("\\u0F4"), vec![(Code::IncompleteEscape, "\\u0F4")]);
    assert_eq!(found("\\U0000"), vec![(Code::IncompleteEscape, "\\U0000")]);
    assert_eq!(found("\\u0F4g"), vec![(Code::InvalidEscape, "\\u0F4")]);
    assert_eq!(found("\\uD800"), vec![(Code::InvalidEscape, "\\uD800")]);
    assert_eq!(
        found("\\UFFFFFFFF"),
        vec![(Code::InvalidEscape, "\\UFFFFFFFF")]
    );
    // Malformed escapes are kept as typed.
    assert_eq!(ewts_to_unicode("\\u0F4g"), "\\u0F4ག");
    assert_eq!(found("\\x"), vec![]);
    assert_eq!(found("\\u0F40"), vec![]);
}

#[test]
fn non_canonical_escape() {
    let c = convert("\\u0F43", Options::default());
    assert_eq!(c.text, "\u{0F43}");
    assert_eq!(c.diagnostics.len(), 1);
    assert_eq!(c.diagnostics[0].code, Code::NonCanonicalEscape);
    assert!(
        c.diagnostics[0].message.contains("U+0F42 U+0FB7"),
        "{}",
        c.diagnostics[0].message
    );
    assert_eq!(found("\\u0F42\\u0FB7"), vec![]);
}

#[test]
fn ambiguous_prefix_stack() {
    assert_eq!(found("gya"), vec![(Code::AmbiguousPrefixStack, "gy")]);
    assert_eq!(found("bra"), vec![(Code::AmbiguousPrefixStack, "br")]);
    assert_eq!(found("dwa"), vec![(Code::AmbiguousPrefixStack, "dw")]);
    assert_eq!(found("mya"), vec![(Code::AmbiguousPrefixStack, "my")]);
    // Not ambiguous: no prefix letter, a longer stack, an explicit dot or plus.
    for input in ["kya", "rgya", "sgra", "g.ya", "g+ya", "bsgrubs"] {
        assert!(
            !codes(input).contains(&Code::AmbiguousPrefixStack),
            "{input:?}"
        );
    }
    // It is only a hint; the output is the stack, as before.
    assert_eq!(ewts_to_unicode("gya"), "གྱ");
    assert_eq!(ewts_to_unicode("g.ya"), "གཡ");
}

#[test]
fn spans_are_utf8_byte_offsets() {
    // "བོད" is three 3-byte characters; the space becomes a tsheg.
    let input = "བོད q";
    let c = convert(input, Options::default());
    assert_eq!(c.diagnostics.len(), 1);
    assert_eq!(c.diagnostics[0].span, 10..11);
    assert_eq!(&input[c.diagnostics[0].span.clone()], "q");

    let input = "é中 ka+";
    let d = &convert(input, Options::default()).diagnostics[0];
    assert_eq!(&input[d.span.clone()], "+");
}

#[test]
fn category_and_severity() {
    let expect = [
        (Code::StrayPlus, Category::Invalid, Severity::Warning),
        (Code::DanglingPlus, Category::Incomplete, Severity::Warning),
        (Code::MarkWithoutBase, Category::Invalid, Severity::Warning),
        (Code::DuplicateMark, Category::Invalid, Severity::Warning),
        (
            Code::UnsupportedCharacter,
            Category::Unsupported,
            Severity::Warning,
        ),
        (Code::StrayTilde, Category::Invalid, Severity::Warning),
        (
            Code::IncompleteTilde,
            Category::Incomplete,
            Severity::Warning,
        ),
        (
            Code::UnterminatedLiteral,
            Category::Incomplete,
            Severity::Warning,
        ),
        (
            Code::IncompleteEscape,
            Category::Incomplete,
            Severity::Warning,
        ),
        (Code::InvalidEscape, Category::Invalid, Severity::Warning),
        (
            Code::NonCanonicalEscape,
            Category::Unicode,
            Severity::Warning,
        ),
        (
            Code::AmbiguousPrefixStack,
            Category::Ambiguous,
            Severity::Info,
        ),
        (Code::DroppedInput, Category::Invalid, Severity::Warning),
        (Code::OmSyllable, Category::Ambiguous, Severity::Info),
        (Code::XSign, Category::Ambiguous, Severity::Info),
        (Code::UnstackedSubjoin, Category::Ambiguous, Severity::Info),
        (
            Code::ReverseUnsupportedCodePoint,
            Category::Unsupported,
            Severity::Warning,
        ),
        (
            Code::ReverseAmbiguousRoot,
            Category::Ambiguous,
            Severity::Info,
        ),
        (
            Code::ReverseNonCanonicalInput,
            Category::Unicode,
            Severity::Info,
        ),
    ];
    for (code, category, severity) in expect {
        assert_eq!(
            (code.category(), code.severity()),
            (category, severity),
            "{code:?}"
        );
    }
    assert_eq!(expect.len(), Code::ALL.len());
}

#[test]
fn code_strings_are_unique_and_namespaced() {
    let mut seen = HashSet::new();
    for code in Code::ALL {
        let s = code.as_str();
        assert!(s.starts_with("ewts.") || s.starts_with("reverse."), "{s}");
        assert!(seen.insert(s), "duplicate {s}");
    }
}

/// Every forward code is produced by at least one input in this file; the
/// reverse codes are exercised in tests/reverse.rs.
#[test]
fn every_code_is_exercised() {
    let inputs = [
        "k+", "k+ g", "M", "kMM", "kaq", "ka~g", "ka~", "ka [abc", "ka\\", "\\u0F4g", "\\u0F43",
        "gya",
    ];
    let seen: HashSet<Code> = inputs.iter().flat_map(|i| codes(i)).collect();
    for code in Code::ALL
        .iter()
        .filter(|c| c.as_str().starts_with("ewts.") && !c.is_diplomatic_only())
    {
        assert!(seen.contains(code), "{code:?} is never produced");
    }
}

#[test]
fn diagnostics_do_not_change_the_text() {
    for input in ["k+", "kMM", "gya", "ka [abc", "\\u0F4g", "q"] {
        assert_eq!(
            convert(input, Options::default()).text,
            ewts_to_unicode(input),
            "{input:?}"
        );
    }
}

fn diplomatic(input: &str) -> ttime_core::Conversion {
    convert(
        input,
        Options {
            precomposed: false,
            diplomatic: true,
        },
    )
}

/// Diplomatic mode reports; it never changes the text.
#[test]
fn diplomatic_mode_does_not_change_the_text() {
    for input in [
        "kaa", "k~Ma", "oM", "X", "ka~X", "ghri", "dhru", "gya", "bod skad", "q", "ka [abc",
    ] {
        assert_eq!(diplomatic(input).text, ewts_to_unicode(input), "{input:?}");
    }
}

/// Each silent choice is reported in diplomatic mode and not otherwise.
#[test]
fn diplomatic_mode_reports_each_silent_choice() {
    let cases = [
        ("kaa", Code::DroppedInput),
        ("k~Ma", Code::DroppedInput),
        ("oM", Code::OmSyllable),
        ("kX", Code::XSign),
        ("ka~X", Code::XSign),
        ("ghri", Code::UnstackedSubjoin),
        ("dhru", Code::UnstackedSubjoin),
        ("gya", Code::AmbiguousPrefixStack),
    ];
    for (input, code) in cases {
        let plain = codes(input);
        let d = diplomatic(input);
        let hit = d.diagnostics.iter().find(|x| x.code == code);
        let hit = hit.unwrap_or_else(|| panic!("{input:?}: {code:?} not reported"));
        assert_eq!(hit.severity, Severity::Warning, "{input:?}");
        if code.is_diplomatic_only() {
            assert!(!plain.contains(&code), "{input:?} reports {code:?} outside diplomatic mode");
        }
    }
}

/// Ordinary, unambiguous input reports nothing extra.
#[test]
fn diplomatic_mode_is_quiet_for_plain_input() {
    for input in ["bod skad", "bkra shis bde legs", "rgyal ba'i mdo", "bsgrubs", "gh+ri", "khong [New York] la phebs song /"] {
        assert!(diplomatic(input).diagnostics.is_empty(), "{input:?}: {:?}", diplomatic(input).diagnostics);
    }
}

#[test]
fn diplomatic_spans_cover_the_input_involved() {
    let d = diplomatic("kaa");
    assert_eq!(d.diagnostics[0].span, 2..3);
    let d = diplomatic("ka oM");
    let om = d.diagnostics.iter().find(|x| x.code == Code::OmSyllable).unwrap();
    assert_eq!(&"ka oM"[om.span.clone()], "oM");
}

#[test]
fn diplomatic_mode_never_changes_text_on_random_input() {
    let alphabet: Vec<char> = "kgyrlhsabdmnoMXA~+.[]\\ -/0123iuUe".chars().collect();
    let mut seed = 0xD1B54A32D192ED03u64;
    let mut next = || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        seed
    };
    for _ in 0..20_000 {
        let len = (next() % 16) as usize;
        let s: String = (0..len)
            .map(|_| alphabet[(next() % alphabet.len() as u64) as usize])
            .collect();
        for precomposed in [false, true] {
            let plain = Options { precomposed, diplomatic: false };
            let dip = Options { precomposed, diplomatic: true };
            let (a, b) = (convert(&s, plain), convert(&s, dip));
            assert_eq!(a.text, b.text, "{s:?}");
            // diplomatic mode only adds to what plain mode reports
            assert!(b.diagnostics.len() >= a.diagnostics.len(), "{s:?}");
            for d in &b.diagnostics {
                assert!(s.is_char_boundary(d.span.start) && s.is_char_boundary(d.span.end), "{s:?}");
            }
        }
    }
}
