//! The stack builder: letters in, one stack out.
//!
//! A stack is an ordered list of consonants (top to bottom), an optional vowel
//! and optional marks. [`build_stack`] says what Unicode that makes and what to
//! type for it: the canonical EWTS (always `+` between letters) and the
//! shortest EWTS that gives exactly the same text. Whatever the converter
//! complains about is passed on, not hidden: Sanskrit allows far more
//! combinations than any list, so the builder reports instead of refusing.
//!
//! Everything goes through [`convert`], so the builder cannot disagree with
//! typing.

use super::{convert, Diagnostic, Options, CONSONANTS, MARKS, SUBJOINED_ONLY, VOWELS};

/// A stack taller than this is almost certainly a mistake.
pub const MAX_LAYERS: usize = 8;

/// Why a stack could not be built. Nothing here is about Tibetan spelling: an
/// unusual stack is built and reported through [`Stack::diagnostics`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StackError {
    NoLetters,
    TooManyLetters,
    UnknownLetter(String),
    /// A letter that exists only subjoined (`W`, `Y`) cannot be the top letter.
    NeedsLetterAbove(String),
    UnknownVowel(String),
    UnknownMark(String),
}

impl std::fmt::Display for StackError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            StackError::NoLetters => write!(f, "a stack needs at least one letter"),
            StackError::TooManyLetters => write!(f, "a stack has at most {MAX_LAYERS} letters"),
            StackError::UnknownLetter(k) => write!(f, "`{k}` is not a letter"),
            StackError::NeedsLetterAbove(k) => {
                write!(
                    f,
                    "`{k}` only exists under another letter, so it cannot be the top of a stack"
                )
            }
            StackError::UnknownVowel(k) => write!(f, "`{k}` is not a vowel"),
            StackError::UnknownMark(k) => write!(f, "`{k}` is not a mark"),
        }
    }
}

impl std::error::Error for StackError {}

/// A finished stack.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Stack {
    /// The Tibetan Unicode.
    pub text: String,
    /// EWTS with `+` between every letter, vowel always written: `k+Sha`.
    pub canonical: String,
    /// The shortest EWTS that converts to the same `text`: `rgya` for
    /// `r+g+ya`. Equal to `canonical` when no `+` can go.
    pub shortest: String,
    /// What the converter said about `canonical` (spans refer to it).
    pub diagnostics: Vec<Diagnostic>,
}

impl Stack {
    /// The code points of `text` as `0F40 0FB5`.
    pub fn code_points(&self) -> String {
        self.text
            .chars()
            .map(|c| format!("{:04X}", c as u32))
            .collect::<Vec<_>>()
            .join(" ")
    }
}

fn assemble(layers: &[&str], plus: &[bool], vowel: &str, marks: &[&str]) -> String {
    let mut s = String::new();
    for (i, key) in layers.iter().enumerate() {
        if i > 0 && plus[i] {
            s.push('+');
        }
        s.push_str(key);
    }
    s.push_str(vowel);
    for m in marks {
        s.push_str(m);
    }
    s
}

/// Builds a stack from consonant keys (top to bottom), a vowel key (`None` or
/// `""` is the inherent `a`) and mark keys. Keys are EWTS: `k`, `Sh`, `ng`, `W`.
pub fn build_stack(
    layers: &[&str],
    vowel: Option<&str>,
    marks: &[&str],
    options: Options,
) -> Result<Stack, StackError> {
    if layers.is_empty() {
        return Err(StackError::NoLetters);
    }
    if layers.len() > MAX_LAYERS {
        return Err(StackError::TooManyLetters);
    }
    let letter_ok = |k: &str| {
        CONSONANTS.iter().any(|c| c.0 == k) || SUBJOINED_ONLY.iter().any(|c| c.0 == k && k != "Z")
    };
    for k in layers {
        if !letter_ok(k) {
            return Err(StackError::UnknownLetter((*k).to_string()));
        }
    }
    if SUBJOINED_ONLY.iter().any(|c| c.0 == layers[0]) {
        return Err(StackError::NeedsLetterAbove(layers[0].to_string()));
    }
    let vowel = match vowel {
        None | Some("") => "a",
        Some(v) => v,
    };
    if !VOWELS.iter().any(|x| x.0 == vowel) {
        return Err(StackError::UnknownVowel(vowel.to_string()));
    }
    for m in marks {
        if !MARKS.iter().any(|x| x.0 == *m) {
            return Err(StackError::UnknownMark((*m).to_string()));
        }
    }

    let plus = vec![true; layers.len()];
    let canonical = assemble(layers, &plus, vowel, marks);
    let converted = convert(&canonical, options);

    // Try every way of dropping pluses and keep the shortest spelling that
    // converts to exactly the same text. Dropping one at a time is not enough:
    // `rg+ya` is not `r+g+ya`, but `rgya` is.
    let gaps = layers.len() - 1;
    let mut shortest = canonical.clone();
    for mask in 1u32..(1u32 << gaps) {
        let plus: Vec<bool> = (0..layers.len())
            .map(|i| i == 0 || mask & (1 << (i - 1)) == 0)
            .collect();
        let candidate = assemble(layers, &plus, vowel, marks);
        if candidate.len() < shortest.len() && convert(&candidate, options).text == converted.text {
            shortest = candidate;
        }
    }

    Ok(Stack {
        text: converted.text,
        canonical,
        shortest,
        diagnostics: converted.diagnostics,
    })
}

/// One thing the user can pick: its EWTS key and an example of how it looks
/// (a consonant on its own; a vowel or mark on ka).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Letter {
    pub key: &'static str,
    pub example: String,
}

/// Everything the stack builder accepts, in a stable order, for pickers.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Alphabet {
    pub consonants: Vec<Letter>,
    /// Letters that exist only in subjoined form (fixed-form `W`, `Y`).
    pub subjoined_only: Vec<Letter>,
    pub vowels: Vec<Letter>,
    pub marks: Vec<Letter>,
}

pub fn stack_alphabet() -> Alphabet {
    let opts = Options::default();
    let on_ka = |key: &str| convert(&format!("k{key}"), opts).text;
    Alphabet {
        consonants: CONSONANTS
            .iter()
            .map(|c| Letter {
                key: c.0,
                example: convert(&format!("{}a", c.0), opts).text,
            })
            .collect(),
        subjoined_only: SUBJOINED_ONLY
            .iter()
            .filter(|c| c.0 != "Z")
            .map(|c| Letter {
                key: c.0,
                example: convert(&format!("k+{}a", c.0), opts).text,
            })
            .collect(),
        vowels: VOWELS
            .iter()
            .filter(|v| v.0 != "a")
            .map(|v| Letter {
                key: v.0,
                example: on_ka(v.0),
            })
            .collect(),
        marks: MARKS
            .iter()
            .map(|m| Letter {
                key: m.0,
                example: convert(&format!("ka{}", m.0), opts).text,
            })
            .collect(),
    }
}

/// [`build_stack`] for the bridges: keys as space-separated strings, the answer
/// as JSON. `{"ok":true,"text","canonical","shortest","codePoints","diagnostics"}`
/// or `{"ok":false,"error"}`. An empty `vowel` is the inherent `a`.
pub fn build_stack_json(layers: &str, vowel: &str, marks: &str, options: Options) -> String {
    use crate::json;
    let layers: Vec<&str> = layers.split_whitespace().collect();
    let marks: Vec<&str> = marks.split_whitespace().collect();
    match build_stack(&layers, Some(vowel), &marks, options) {
        Ok(s) => format!(
            "{{\"ok\":true,\"text\":{},\"canonical\":{},\"shortest\":{},\"codePoints\":{},\"diagnostics\":{}}}",
            json::string(&s.text),
            json::string(&s.canonical),
            json::string(&s.shortest),
            json::string(&s.code_points()),
            json::diagnostics(&s.diagnostics)
        ),
        Err(e) => format!("{{\"ok\":false,\"error\":{}}}", json::string(&e.to_string())),
    }
}

/// [`stack_alphabet`] as JSON:
/// `{"consonants":[{"key","example"}],"subjoinedOnly":[...],"vowels":[...],"marks":[...]}`.
pub fn stack_alphabet_json() -> String {
    use crate::json;
    let a = stack_alphabet();
    let list = |ls: &[Letter]| {
        let items: Vec<String> = ls
            .iter()
            .map(|l| {
                format!(
                    "{{\"key\":{},\"example\":{}}}",
                    json::string(l.key),
                    json::string(&l.example)
                )
            })
            .collect();
        format!("[{}]", items.join(","))
    };
    format!(
        "{{\"consonants\":{},\"subjoinedOnly\":{},\"vowels\":{},\"marks\":{}}}",
        list(&a.consonants),
        list(&a.subjoined_only),
        list(&a.vowels),
        list(&a.marks)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn build(layers: &[&str], vowel: Option<&str>, marks: &[&str]) -> Stack {
        build_stack(layers, vowel, marks, Options::default()).unwrap()
    }

    #[test]
    fn a_single_letter_is_just_that_letter() {
        let s = build(&["k"], None, &[]);
        assert_eq!(
            (s.canonical.as_str(), s.shortest.as_str(), s.text.as_str()),
            ("ka", "ka", "ཀ")
        );
    }

    #[test]
    fn kssa_needs_its_plus() {
        let s = build(&["k", "Sh"], None, &[]);
        assert_eq!(s.canonical, "k+Sha");
        assert_eq!(s.text, "\u{0F40}\u{0FB5}");
        assert_eq!(s.code_points(), "0F40 0FB5");
        assert_eq!(s.shortest, s.canonical, "no shorter spelling gives kṣa");
    }

    #[test]
    fn standard_tibetan_stacks_lose_their_pluses() {
        assert_eq!(build(&["r", "g", "y"], None, &[]).shortest, "rgya");
        assert_eq!(build(&["s", "k", "r"], None, &[]).shortest, "skra");
        assert_eq!(
            build(&["b", "s", "k", "r"], None, &[]).canonical,
            "b+s+k+ra"
        );
    }

    #[test]
    fn a_plus_that_would_change_the_letter_stays() {
        // `t` + `s` is not `ts` (the letter tsa), so the plus has to stay.
        let t = build(&["t", "s"], None, &[]);
        assert_eq!(t.shortest, "t+sa");
        assert_ne!(t.text, convert("tsa", Options::default()).text);
        // `dh` is by definition `d` plus subjoined `h`, so here the plus can go.
        assert_eq!(build(&["d", "h"], None, &[]).shortest, "dha");
    }

    #[test]
    fn vowels_and_marks_are_part_of_the_code() {
        let s = build(&["k", "Sh"], Some("i"), &["M"]);
        assert_eq!(s.canonical, "k+ShiM");
        assert_eq!(convert("k+ShiM", Options::default()).text, s.text);
        let v = build(&["k", "r"], Some("-i"), &[]);
        assert_eq!(v.canonical, "k+r-i");
        assert_eq!(v.shortest, "kr-i");
    }

    #[test]
    fn bad_input_is_refused_with_a_reason() {
        let o = Options::default();
        assert_eq!(build_stack(&[], None, &[], o), Err(StackError::NoLetters));
        assert_eq!(
            build_stack(&["q"], None, &[], o),
            Err(StackError::UnknownLetter("q".into()))
        );
        assert_eq!(
            build_stack(&["k"], Some("x"), &[], o),
            Err(StackError::UnknownVowel("x".into()))
        );
        assert_eq!(
            build_stack(&["k"], None, &["Q"], o),
            Err(StackError::UnknownMark("Q".into()))
        );
        assert_eq!(
            build_stack(&["k"; 9], None, &[], o),
            Err(StackError::TooManyLetters)
        );
        assert_eq!(
            build_stack(&["Z"], None, &[], o),
            Err(StackError::UnknownLetter("Z".into()))
        );
        assert_eq!(
            build_stack(&["W", "k"], None, &[], o),
            Err(StackError::NeedsLetterAbove("W".into()))
        );
        assert!(build_stack(&["k", "W"], None, &[], o).is_ok());
    }

    #[test]
    fn the_alphabet_lists_what_the_builder_accepts() {
        let a = stack_alphabet();
        assert!(a
            .consonants
            .iter()
            .any(|l| l.key == "k" && l.example == "ཀ"));
        assert!(a.vowels.iter().any(|l| l.key == "i"));
        assert!(a.marks.iter().any(|l| l.key == "M"));
        for l in &a.consonants {
            assert!(
                build_stack(&[l.key], None, &[], Options::default()).is_ok(),
                "{}",
                l.key
            );
        }
        for l in &a.subjoined_only {
            assert!(
                build_stack(&["k", l.key], None, &[], Options::default()).is_ok(),
                "{}",
                l.key
            );
        }
        for l in &a.vowels {
            assert!(
                build_stack(&["k"], Some(l.key), &[], Options::default()).is_ok(),
                "{}",
                l.key
            );
        }
        for l in &a.marks {
            assert!(
                build_stack(&["k"], None, &[l.key], Options::default()).is_ok(),
                "{}",
                l.key
            );
        }
    }

    /// The coverage check: every pair of letters builds with no complaint from
    /// the converter, and the shortest spelling always converts to the same
    /// text as the canonical one.
    #[test]
    fn every_pair_builds_cleanly_and_the_shortest_spelling_is_faithful() {
        let a = stack_alphabet();
        let tops: Vec<&str> = a.consonants.iter().map(|l| l.key).collect();
        let bottoms: Vec<&str> = tops
            .iter()
            .copied()
            .chain(a.subjoined_only.iter().map(|l| l.key))
            .collect();
        let o = Options::default();
        let mut pairs = 0;
        for top in &tops {
            for bottom in &bottoms {
                let s = build_stack(&[top, bottom], None, &[], o).unwrap();
                assert!(
                    s.diagnostics.is_empty(),
                    "{top}+{bottom}: {:?}",
                    s.diagnostics
                );
                assert_eq!(
                    convert(&s.shortest, o).text,
                    s.text,
                    "{top}+{bottom} -> {}",
                    s.shortest
                );
                assert!(s.shortest.len() <= s.canonical.len());
                pairs += 1;
            }
        }
        assert!(pairs > 1800, "{pairs}");
    }

    #[test]
    fn triples_of_common_sanskrit_letters_are_faithful() {
        let letters = [
            "k", "g", "t", "d", "n", "p", "m", "y", "r", "l", "w", "s", "sh", "Sh", "T", "N", "dh",
            "bh",
        ];
        let o = Options::default();
        for a in letters {
            for b in letters {
                for c in letters {
                    let s = build_stack(&[a, b, c], None, &[], o).unwrap();
                    assert_eq!(
                        convert(&s.shortest, o).text,
                        s.text,
                        "{a}+{b}+{c} -> {}",
                        s.shortest
                    );
                }
            }
        }
    }

    #[test]
    fn the_json_forms_carry_the_same_answer() {
        let o = Options::default();
        let j = build_stack_json("r g y", "", "", o);
        assert!(j.starts_with("{\"ok\":true,\"text\":\"རྒྱ\""), "{j}");
        assert!(j.contains("\"canonical\":\"r+g+ya\""), "{j}");
        assert!(j.contains("\"shortest\":\"rgya\""), "{j}");
        assert!(j.contains("\"codePoints\":\"0F62 0F92 0FB1\""), "{j}");
        assert_eq!(
            build_stack_json("W k", "", "", o),
            "{\"ok\":false,\"error\":\"`W` only exists under another letter, so it cannot be the top of a stack\"}"
        );
        let a = stack_alphabet_json();
        assert!(a.starts_with("{\"consonants\":[{\"key\":"), "{a}");
        assert!(a.contains("\"subjoinedOnly\":[{\"key\":\"W\""), "{a}");
    }
}
