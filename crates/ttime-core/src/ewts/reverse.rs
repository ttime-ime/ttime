//! Tibetan Unicode to EWTS.
//!
//! The converter never guesses silently. Each syllable is spelled with the
//! most idiomatic EWTS first (implicit stacks, no separators), then checked by
//! running the forward converter on that spelling; if the check fails the
//! spelling is made more explicit (`.` between stacks, then `+` inside every
//! stack). Anything with no EWTS spelling is written as a `\uXXXX` escape, so
//! no input is ever dropped.
//!
//! Round-trip classes, measured by the forward converter with default options:
//!
//! * [`Fidelity::Exact`]: `forward(reverse(u)) == u`.
//! * [`Fidelity::Canonical`]: equal after canonical normalisation (precomposed
//!   characters such as U+0F43 decomposed, marks in canonical order).
//! * [`Fidelity::Lossy`]: anything else. The spelling is still the best
//!   available and is reported, not hidden.

use super::{
    canonical_order, combining_class, convert, legal_stack, Code, Diagnostic, Options, CONSONANTS,
    NYIS_SHAD, PRECOMPOSED, SHAD, TSHEG,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Fidelity {
    Exact,
    Canonical,
    Lossy,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reverse {
    pub text: String,
    pub diagnostics: Vec<Diagnostic>,
    pub fidelity: Fidelity,
}

/// A character of the normalised input and where it came from (UTF-8 bytes).
#[derive(Clone, Copy)]
struct Ch {
    c: char,
    start: usize,
    end: usize,
}

fn is_base(c: char) -> bool {
    ('\u{0F40}'..='\u{0F6C}').contains(&c)
}

fn is_subjoined(c: char) -> bool {
    ('\u{0F90}'..='\u{0FBC}').contains(&c)
}

fn is_vowel_sign(c: char) -> bool {
    matches!(c, '\u{0F71}'..='\u{0F7D}' | '\u{0F80}')
}

fn is_tail_mark(c: char) -> bool {
    matches!(
        c,
        '\u{0F7E}' | '\u{0F7F}' | '\u{0F82}'..='\u{0F85}' | '\u{0F35}' | '\u{0F37}' | '\u{0F39}'
    )
}

fn is_tail(c: char) -> bool {
    is_vowel_sign(c) || is_tail_mark(c)
}

fn base_key(c: char) -> Option<&'static str> {
    CONSONANTS
        .iter()
        .find(|&&(_, cp, tail)| cp == c && tail.is_none())
        .map(|&(k, _, _)| k)
}

fn sub_key(c: char) -> Option<&'static str> {
    match c {
        '\u{0FBA}' => Some("W"),
        '\u{0FBB}' => Some("Y"),
        '\u{0FBC}' => Some("R"),
        _ => base_key(char::from_u32(c as u32 - 0x50)?),
    }
}

fn mark_token(c: char) -> Option<&'static str> {
    Some(match c {
        '\u{0F7E}' => "M",
        '\u{0F7F}' => "H",
        '\u{0F82}' => "~M`",
        '\u{0F83}' => "~M",
        '\u{0F35}' => "~X",
        '\u{0F37}' => "X",
        '\u{0F39}' => "^",
        '\u{0F84}' => "?",
        '\u{0F85}' => "&",
        _ => return None,
    })
}

fn vowel_token(signs: &[char]) -> Option<&'static str> {
    Some(match signs {
        [] => "a",
        ['\u{0F72}'] => "i",
        ['\u{0F74}'] => "u",
        ['\u{0F7A}'] => "e",
        ['\u{0F7C}'] => "o",
        ['\u{0F71}'] => "A",
        ['\u{0F71}', '\u{0F72}'] => "I",
        ['\u{0F71}', '\u{0F74}'] => "U",
        ['\u{0F7B}'] => "ai",
        ['\u{0F7D}'] => "au",
        ['\u{0F80}'] => "-i",
        ['\u{0F71}', '\u{0F80}'] => "-I",
        ['\u{0F7C}', '\u{0F74}'] => "uo",
        ['\u{0F72}', '\u{0F74}'] => "ui",
        ['\u{0F7A}', '\u{0F74}'] => "ue",
        _ => return None,
    })
}

fn punctuation_token(c: char) -> Option<&'static str> {
    Some(match c {
        TSHEG => " ",
        ' ' => "_",
        SHAD => "/",
        NYIS_SHAD => "//",
        '\u{0F0C}' => "*",
        '\u{0F0F}' => ";",
        '\u{0F11}' => "|",
        '\u{0F08}' => "!",
        '\u{0F14}' => ":",
        '\u{0F34}' => "=",
        '\u{0F04}' => "@",
        '\u{0F05}' => "#",
        '\u{0F06}' => "$",
        '\u{0F07}' => "%",
        '\u{0F3A}' => "<",
        '\u{0F3B}' => ">",
        '\u{0F3C}' => "(",
        '\u{0F3D}' => ")",
        '\u{0F00}' => "oM",
        _ => return None,
    })
}

fn escape(c: char) -> String {
    if (c as u32) > 0xFFFF {
        format!("\\U{:08X}", c as u32)
    } else {
        format!("\\u{:04X}", c as u32)
    }
}

/// What follows a stack's letters, in the order it appears in the text. Order
/// matters: U+0F7E and U+0F7F are not reordered by normalisation, so `M` then
/// `A` and `A` then `M` are different strings.
enum Tail {
    Vowel(&'static str),
    Mark(&'static str),
}

/// A base letter and its subjoined letters, then the vowel signs and marks
/// that follow, all as EWTS tokens.
struct Stack {
    letters: Vec<&'static str>,
    tail: Vec<Tail>,
    start: usize,
    end: usize,
    /// The base was a-chen (U+0F68) on its own.
    a_chen: bool,
}

impl Stack {
    fn has_vowel_sign(&self) -> bool {
        // a-chen is itself a vowel carrier, so it is always a root.
        self.a_chen || self.tail.iter().any(|t| matches!(t, Tail::Vowel(_)))
    }

    fn starts_with_vowel(&self) -> bool {
        matches!(self.tail.first(), Some(Tail::Vowel(_)))
    }

    fn text(&self, plus: bool) -> String {
        let sep = if plus { "+" } else { "" };
        self.letters.join(sep)
    }
}

/// Parses one stack starting at `chars[i]` (a base letter). Returns `None` if
/// the combination has no EWTS spelling.
fn parse_stack(chars: &[Ch], i: usize) -> Option<(Stack, usize)> {
    let start = chars[i].start;
    let base = chars[i].c;
    let mut j = i + 1;
    let mut letters: Vec<&'static str> = Vec::new();
    let mut a_chen = false;

    let mut tail_start = j;
    while tail_start < chars.len() && is_subjoined(chars[tail_start].c) {
        tail_start += 1;
    }
    let subs: Vec<char> = chars[j..tail_start].iter().map(|c| c.c).collect();
    j = tail_start;
    let mut k = j;
    while k < chars.len() && is_tail(chars[k].c) {
        k += 1;
    }
    let tail: Vec<char> = chars[j..k].iter().map(|c| c.c).collect();

    // f and v are a letter plus U+0F39.
    let mut tail = tail;
    let mut subs = subs;
    let mut f_or_v = None;
    if matches!(base, '\u{0F55}' | '\u{0F56}')
        && subs.is_empty()
        && tail.first() == Some(&'\u{0F39}')
    {
        f_or_v = Some(if base == '\u{0F55}' { "f" } else { "v" });
        tail.remove(0);
    }

    if base == '\u{0F68}' {
        if !subs.is_empty() {
            return None;
        }
        a_chen = true;
    } else if let Some(fv) = f_or_v {
        letters.push(fv);
    } else if let (Some(&'\u{0FB7}'), Some(key)) = (
        subs.first(),
        match base {
            '\u{0F42}' => Some("gh"),
            '\u{0F51}' => Some("dh"),
            '\u{0F4C}' => Some("Dh"),
            '\u{0F56}' => Some("bh"),
            '\u{0F5B}' => Some("dzh"),
            _ => None,
        },
    ) {
        letters.push(key);
        subs.remove(0);
    } else {
        letters.push(base_key(base)?);
    }

    // Subjoined f and v: a subjoined letter followed by U+0F39 in the tail is
    // not representable (the tail would be taken as a mark); keep it simple.
    for s in subs {
        letters.push(sub_key(s)?);
    }

    let mut tokens = Vec::new();
    let mut t = 0;
    while t < tail.len() {
        if is_vowel_sign(tail[t]) {
            let run = tail[t..].iter().take_while(|&&c| is_vowel_sign(c)).count();
            tokens.push(Tail::Vowel(vowel_token(&tail[t..t + run])?));
            t += run;
        } else {
            tokens.push(Tail::Mark(mark_token(tail[t])?));
            t += 1;
        }
    }

    let end = chars[k - 1].end;
    Some((
        Stack {
            letters,
            tail: tokens,
            start,
            end,
            a_chen,
        },
        k,
    ))
}

const PREFIXES: &[&str] = &["g", "d", "b", "m", "'"];
const SUFFIXES: &[&str] = &["g", "ng", "d", "n", "b", "m", "'", "r", "l", "s"];

/// Which stack is the root, and whether that was a guess.
fn pick_root(stacks: &[Stack]) -> (usize, bool) {
    if let Some(i) = stacks.iter().position(|s| s.has_vowel_sign()) {
        return (i, false);
    }
    // A multi-letter stack that is a standard Tibetan stack is the root; a
    // Sanskrit-style stack (one that needs `+`) is a syllable of its own.
    if let Some(i) = stacks
        .iter()
        .position(|s| s.letters.len() > 1 && legal_stack(&s.letters))
    {
        return (i, false);
    }
    let single = |i: usize| stacks[i].letters[0];
    match stacks.len() {
        1 => (0, false),
        // Two single letters: root + suffix, unless the second cannot be a
        // suffix and the first can be a prefix (g.ya, d.ra).
        2 if PREFIXES.contains(&single(0)) && !SUFFIXES.contains(&single(1)) => (1, true),
        2 => (0, true),
        3 => {
            let suffix_pair = SUFFIXES.contains(&single(1)) && matches!(single(2), "s" | "d");
            if PREFIXES.contains(&single(0)) && !suffix_pair {
                (1, true)
            } else {
                (0, true)
            }
        }
        _ => {
            if PREFIXES.contains(&single(0)) {
                (1, true)
            } else {
                (0, true)
            }
        }
    }
}

/// How explicit to be when spelling a syllable.
#[derive(Clone, Copy, PartialEq)]
enum Style {
    Implicit,
    Dotted,
    Explicit,
}

fn spell_syllable(stacks: &[Stack], root: usize, style: Style) -> String {
    let plus = style == Style::Explicit;
    let mut out = String::new();
    for (i, s) in stacks.iter().enumerate() {
        if i > 0 && style != Style::Implicit {
            out.push('.');
        }
        if s.a_chen {
            if !s.starts_with_vowel() {
                out.push('a');
            }
        } else {
            if s.letters.len() > 1 && !plus && !legal_stack(&s.letters) {
                out.push_str(&s.letters.join("+"));
            } else {
                out.push_str(&s.text(plus));
            }
            if !s.starts_with_vowel()
                && (i == root || (s.letters.len() > 1 && !legal_stack(&s.letters)))
            {
                out.push('a');
            }
        }
        for t in &s.tail {
            match t {
                Tail::Vowel(v) | Tail::Mark(v) => out.push_str(v),
            }
        }
    }
    out
}

/// Canonical normal form for the Tibetan block: composition exclusions
/// decomposed, combining marks in canonical order.
pub(super) fn normalize(text: &str) -> String {
    let mut out = String::new();
    for c in text.chars() {
        match PRECOMPOSED.iter().find(|(_, to)| *to == c) {
            Some((from, _)) => out.push_str(from),
            None => out.push(c),
        }
    }
    canonical_order(&out)
}

pub fn unicode_to_ewts(input: &str) -> Reverse {
    let mut diags: Vec<Diagnostic> = Vec::new();

    // Normalise, remembering where each character came from.
    let mut chars: Vec<Ch> = Vec::new();
    for (start, c) in input.char_indices() {
        let end = start + c.len_utf8();
        match PRECOMPOSED.iter().find(|(_, to)| *to == c) {
            Some((from, _)) => {
                diags.push(Diagnostic::new(
                    Code::ReverseNonCanonicalInput,
                    start..end,
                    format!("U+{:04X} is read as its canonical decomposition", c as u32),
                ));
                chars.extend(from.chars().map(|c| Ch { c, start, end }));
            }
            None => chars.push(Ch { c, start, end }),
        }
    }
    let mut i = 0;
    while i < chars.len() {
        if combining_class(chars[i].c) == 0 {
            i += 1;
            continue;
        }
        let mut j = i;
        while j < chars.len() && combining_class(chars[j].c) > 0 {
            j += 1;
        }
        let before: Vec<char> = chars[i..j].iter().map(|c| c.c).collect();
        chars[i..j].sort_by_key(|c| combining_class(c.c));
        if chars[i..j].iter().map(|c| c.c).ne(before.iter().copied()) {
            diags.push(Diagnostic::new(
                Code::ReverseNonCanonicalInput,
                chars[i].start.min(chars[j - 1].start)..chars[i].end.max(chars[j - 1].end),
                "combining marks are not in canonical order; they are reordered".to_string(),
            ));
        }
        i = j;
    }

    let mut out = String::new();
    let mut literal = String::new();
    let flush_literal = |out: &mut String, literal: &mut String| {
        if !literal.is_empty() {
            out.push('[');
            out.push_str(literal);
            out.push(']');
            literal.clear();
        }
    };

    let mut after_syllable = false;
    let mut i = 0;
    while i < chars.len() {
        let Ch { c, start, end } = chars[i];

        if is_base(c) {
            // Gather the stacks of one syllable.
            let first = i;
            let mut stacks = Vec::new();
            let mut j = i;
            while j < chars.len() && is_base(chars[j].c) {
                match parse_stack(&chars, j) {
                    Some((s, next)) => {
                        stacks.push(s);
                        j = next;
                    }
                    None => break,
                }
            }
            if stacks.is_empty() {
                flush_literal(&mut out, &mut literal);
                after_syllable = false;
                out.push_str(&escape(c));
                diags.push(Diagnostic::new(
                    Code::ReverseUnsupportedCodePoint,
                    start..end,
                    format!(
                        "U+{:04X} with its marks has no EWTS spelling; written as an escape",
                        c as u32
                    ),
                ));
                i += 1;
                continue;
            }
            flush_literal(&mut out, &mut literal);
            let (root, guessed) = pick_root(&stacks);
            let expected: String = chars[first..j].iter().map(|c| c.c).collect();
            let mut chosen = String::new();
            for style in [Style::Implicit, Style::Dotted, Style::Explicit] {
                chosen = spell_syllable(&stacks, root, style);
                if convert(&chosen, Options::default()).text == expected {
                    break;
                }
            }
            if guessed {
                diags.push(Diagnostic::new(
                    Code::ReverseAmbiguousRoot,
                    stacks[0].start..stacks[stacks.len() - 1].end,
                    format!("no vowel sign marks the root letter; \"{chosen}\" assumes stack {} is the root", root + 1),
                ));
            }
            out.push_str(&chosen);
            after_syllable = true;
            i = j;
            continue;
        }

        match c {
            '\u{0F20}'..='\u{0F29}' => {
                flush_literal(&mut out, &mut literal);
                out.push(char::from_digit(c as u32 - 0x0F20, 10).unwrap());
            }
            '\u{0F2A}'..='\u{0F33}' => {
                flush_literal(&mut out, &mut literal);
                out.push('-');
                out.push(char::from_digit((c as u32 - 0x0F2A + 1) % 10, 10).unwrap());
            }
            _ if punctuation_token(c).is_some() => {
                flush_literal(&mut out, &mut literal);
                // "oM" is only recognised at the start of a syllable.
                if c == '\u{0F00}' && after_syllable {
                    out.push('.');
                }
                out.push_str(punctuation_token(c).unwrap());
            }
            '\n' | '\r' | '\t' => {
                flush_literal(&mut out, &mut literal);
                out.push(c);
            }
            ']' => {
                flush_literal(&mut out, &mut literal);
                out.push_str("\\u005D");
            }
            _ if ('\u{0F00}'..='\u{0FFF}').contains(&c) => {
                flush_literal(&mut out, &mut literal);
                out.push_str(&escape(c));
                diags.push(Diagnostic::new(
                    Code::ReverseUnsupportedCodePoint,
                    start..end,
                    format!(
                        "U+{:04X} has no EWTS spelling; written as an escape",
                        c as u32
                    ),
                ));
            }
            _ => literal.push(c),
        }
        after_syllable = false;
        i += 1;
    }
    flush_literal(&mut out, &mut literal);

    let back = convert(&out, Options::default()).text;
    let fidelity = if back == input {
        Fidelity::Exact
    } else if normalize(&back) == normalize(input) {
        Fidelity::Canonical
    } else {
        Fidelity::Lossy
    };
    diags.sort_by_key(|d| (d.span.start, d.span.end));
    Reverse {
        text: out,
        diagnostics: diags,
        fidelity,
    }
}
