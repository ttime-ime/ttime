//! EWTS (Extended Wylie Transliteration Scheme) to Tibetan Unicode.
//!
//! Supported: the thirty Tibetan consonants, Sanskrit retroflexes (`T Th D N
//! Sh`), the vowels `a i u e o A I U ai au -i -I`, `M` and `H`, explicit
//! stacking with `+`, implicit stacking by the legal-stack tables, digits and
//! basic punctuation. A space is a tsheg and `_` is a real space.

mod diagnostics;
mod reverse;

pub use diagnostics::{Category, Code, Conversion, Diagnostic, Severity};
pub use reverse::{unicode_to_ewts, Fidelity, Reverse};

const A_CHEN: char = '\u{0F68}';
const TSHEG: char = '\u{0F0B}';
const SHAD: char = '\u{0F0D}';
const NYIS_SHAD: char = '\u{0F0E}';
const SUBJOINED_OFFSET: u32 = 0x50;

/// A consonant: EWTS key, code point, and an optional combining mark that
/// follows it (`gh` is ga + subjoined ha, `f` is pa + U+0F39).
type Cons = (&'static str, char, Option<char>);

/// Longest keys first so greedy matching works.
const CONSONANTS: &[Cons] = &[
    ("dzh", '\u{0F5B}', Some('\u{0FB7}')),
    ("tsh", '\u{0F5A}', None),
    ("gh", '\u{0F42}', Some('\u{0FB7}')),
    ("dh", '\u{0F51}', Some('\u{0FB7}')),
    ("bh", '\u{0F56}', Some('\u{0FB7}')),
    ("Dh", '\u{0F4C}', Some('\u{0FB7}')),
    ("ts", '\u{0F59}', None),
    ("dz", '\u{0F5B}', None),
    ("zh", '\u{0F5E}', None),
    ("sh", '\u{0F64}', None),
    ("kh", '\u{0F41}', None),
    ("ng", '\u{0F44}', None),
    ("ch", '\u{0F46}', None),
    ("ny", '\u{0F49}', None),
    ("th", '\u{0F50}', None),
    ("ph", '\u{0F55}', None),
    ("Th", '\u{0F4B}', None),
    ("Sh", '\u{0F65}', None),
    ("f", '\u{0F55}', Some('\u{0F39}')),
    ("v", '\u{0F56}', Some('\u{0F39}')),
    ("R", '\u{0F6A}', None),
    ("k", '\u{0F40}', None),
    ("g", '\u{0F42}', None),
    ("c", '\u{0F45}', None),
    ("j", '\u{0F47}', None),
    ("t", '\u{0F4F}', None),
    ("d", '\u{0F51}', None),
    ("n", '\u{0F53}', None),
    ("p", '\u{0F54}', None),
    ("b", '\u{0F56}', None),
    ("m", '\u{0F58}', None),
    ("w", '\u{0F5D}', None),
    ("z", '\u{0F5F}', None),
    ("'", '\u{0F60}', None),
    ("y", '\u{0F61}', None),
    ("r", '\u{0F62}', None),
    ("l", '\u{0F63}', None),
    ("s", '\u{0F66}', None),
    ("h", '\u{0F67}', None),
    ("T", '\u{0F4A}', None),
    ("D", '\u{0F4C}', None),
    ("N", '\u{0F4E}', None),
];

/// Letters that exist only as subjoined forms, reachable after `+`:
/// fixed-form wa (`W`), fixed-form ya (`Y`) and the tsa-phru mark (`Z`).
const SUBJOINED_ONLY: &[Cons] = &[
    ("W", '\u{0FBA}', None),
    ("Y", '\u{0FBB}', None),
    ("Z", '\u{0F39}', None),
];

/// Longest keys first. `a` outputs nothing: it is the inherent vowel.
const VOWELS: &[(&str, &str)] = &[
    ("-I", "\u{0F71}\u{0F80}"),
    ("uo", "\u{0F7C}\u{0F74}"),
    ("ui", "\u{0F72}\u{0F74}"),
    ("ue", "\u{0F7A}\u{0F74}"),
    ("-i", "\u{0F80}"),
    ("ai", "\u{0F7B}"),
    ("au", "\u{0F7D}"),
    ("A", "\u{0F71}"),
    ("I", "\u{0F71}\u{0F72}"),
    ("U", "\u{0F71}\u{0F74}"),
    ("a", ""),
    ("i", "\u{0F72}"),
    ("u", "\u{0F74}"),
    ("e", "\u{0F7A}"),
    ("o", "\u{0F7C}"),
];

const MARKS: &[(&str, char)] = &[
    ("~M`", '\u{0F82}'),
    ("~M", '\u{0F83}'),
    ("~X", '\u{0F35}'),
    ("M", '\u{0F7E}'),
    ("H", '\u{0F7F}'),
    ("X", '\u{0F37}'),
    ("^", '\u{0F39}'),
    ("?", '\u{0F84}'),
    ("&", '\u{0F85}'),
];

/// Consonant sequences that stack without an explicit `+`: the standard
/// Tibetan stacks and the few Sanskrit-derived ones in common use. The
/// inventory is the intersection-and-union of two independent sources, the
/// THL "standard stacks" list as published in m17n's `bo-ewts` and in
/// pyewts (Apache-2.0); see docs/specification/ewts.md, section 3.
const STANDARD_STACKS: &[&str] = &[
    "b+l", "b+r", "b+y", "c+w", "d+r", "d+w", "dz+r", "g+l", "g+r", "g+w", "g+y", "h+r", "h+w",
    "k+l", "k+r", "k+w", "k+y", "kh+r", "kh+w", "kh+y", "l+b", "l+c", "l+d", "l+g", "l+h", "l+j",
    "l+k", "l+ng", "l+p", "l+t", "l+w", "m+r", "m+y", "n+r", "ny+w", "p+r", "p+y", "ph+r", "ph+y",
    "r+b", "r+d", "r+dz", "r+g", "r+j", "r+k", "r+l", "r+m", "r+n", "r+ng", "r+ny", "r+t", "r+ts",
    "r+w", "s+b", "s+d", "s+g", "s+k", "s+l", "s+m", "s+n", "s+ng", "s+ny", "s+p", "s+r", "s+t",
    "s+ts", "s+w", "sh+r", "sh+w", "t+r", "t+w", "th+r", "ts+w", "tsh+w", "z+l", "z+w", "zh+w",
    "d+r+w", "g+r+w", "ph+y+w", "r+g+w", "r+g+y", "r+k+y", "r+m+y", "r+ts+w", "s+b+r", "s+b+y",
    "s+g+r", "s+g+y", "s+k+r", "s+k+y", "s+m+r", "s+m+y", "s+n+r", "s+p+r", "s+p+y",
];

/// Is this consonant sequence a standard stack, so it can be joined without
/// an explicit `+`?
fn legal_stack(keys: &[&str]) -> bool {
    match keys.len() {
        0 => false,
        1 => true,
        _ => STANDARD_STACKS.contains(&keys.join("+").as_str()),
    }
}

#[derive(Debug, Clone)]
struct Cluster {
    cons: Vec<Cons>,
    /// Joined with `+`; never merged with its neighbours.
    forced: bool,
    /// Span in `char` indices of the input.
    start: usize,
    end: usize,
}

#[derive(Debug, Clone)]
enum Item {
    Cons(Cluster),
    Vowel(&'static str),
    Mark(char),
}

/// A lexed item and its span in `char` indices of the input.
#[derive(Debug, Clone)]
struct Tok {
    item: Item,
    start: usize,
    end: usize,
}

fn lex_consonant(chars: &[char]) -> Option<(Cons, usize)> {
    CONSONANTS.iter().find_map(|&(key, cp, tail)| {
        let n = key.chars().count();
        let matches = chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b);
        matches.then_some(((key, cp, tail), n))
    })
}

fn lex_subjoined_only(chars: &[char]) -> Option<(Cons, usize)> {
    let &c = chars.first()?;
    SUBJOINED_ONLY
        .iter()
        .find(|(key, _, _)| key.starts_with(c))
        .map(|&cons| (cons, 1))
}

fn lex(chars: &[char]) -> Option<(Item, usize)> {
    if let Some((key, out)) = VOWELS.iter().find(|(key, _)| {
        let n = key.chars().count();
        chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b)
    }) {
        return Some((Item::Vowel(out), key.chars().count()));
    }
    if let Some((c, n)) = lex_consonant(chars) {
        return Some((
            Item::Cons(Cluster {
                cons: vec![c],
                forced: false,
                start: 0,
                end: 0,
            }),
            n,
        ));
    }
    if let Some(&(key, cp)) = MARKS.iter().find(|(key, _)| {
        let n = key.chars().count();
        chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b)
    }) {
        return Some((Item::Mark(cp), key.chars().count()));
    }
    None
}

fn subjoined(cp: char) -> char {
    match cp {
        // Fixed-form ra has its own subjoined form outside the +0x50 block.
        '\u{0F6A}' => '\u{0FBC}',
        // Already subjoined or combining: fixed-form wa and ya, and U+0F39.
        '\u{0FBA}' | '\u{0FBB}' | '\u{0F39}' => cp,
        _ => char::from_u32(cp as u32 + SUBJOINED_OFFSET).unwrap_or(cp),
    }
}

fn emit_stack(cons: &[Cons], out: &mut String) {
    for (i, &(_, cp, tail)) in cons.iter().enumerate() {
        out.push(if i == 0 { cp } else { subjoined(cp) });
        out.extend(tail);
    }
}

fn emit_cluster(c: &Cluster, out: &mut String) {
    emit_stack(&c.cons, out);
}

/// A syllable's opening run: any prefix letters, then the root stack that
/// carries the vowel.
fn emit_root_run(
    run: &[&Cluster],
    vowel: Option<&str>,
    out: &mut String,
    diags: &mut Vec<Diagnostic>,
) {
    let n = run.len();
    let last_forced = run[n - 1].forced;
    let lower = run[..n - 1]
        .iter()
        .rposition(|c| c.forced)
        .map_or(0, |p| p + 1);

    let start = if last_forced {
        n - 1
    } else {
        (lower..n)
            .find(|&s| {
                let keys: Vec<&str> = run[s..].iter().map(|c| c.cons[0].0).collect();
                legal_stack(&keys)
            })
            .unwrap_or(n - 1)
    };

    // "gya" is the stack g+y; the prefix reading is "g.ya".
    if start == 0 && n == 2 && !run[0].forced && !run[1].forced {
        let (a, b) = (run[0].cons[0].0, run[1].cons[0].0);
        if matches!(a, "b" | "d" | "g" | "m")
            && matches!(b, "y" | "r" | "l" | "w")
            && legal_stack(&[a, b])
        {
            diags.push(Diagnostic::new(
                Code::AmbiguousPrefixStack,
                run[0].start..run[1].end,
                format!(
                    "\"{a}{b}\" is read as one stack; type \"{a}.{b}\" for the prefix \"{a}\" followed by \"{b}\""
                ),
            ));
        }
    }

    for c in &run[..start] {
        emit_cluster(c, out);
    }
    let stack: Vec<Cons> = run[start..]
        .iter()
        .flat_map(|c| c.cons.iter().copied())
        .collect();
    emit_stack(&stack, out);
    if let Some(v) = vowel {
        out.push_str(v);
    }
}

fn convert_syllable(toks: &[Tok], out: &mut String, diags: &mut Vec<Diagnostic>) {
    let mut i = 0;
    let mut first = true;
    while i < toks.len() {
        let mut run: Vec<&Cluster> = Vec::new();
        while let Some(Tok {
            item: Item::Cons(c),
            ..
        }) = toks.get(i)
        {
            run.push(c);
            i += 1;
        }
        let vowel = match toks.get(i) {
            Some(Tok {
                item: Item::Vowel(v),
                ..
            }) => {
                i += 1;
                Some(*v)
            }
            _ => None,
        };
        let have_base = !run.is_empty() || vowel.is_some();

        if first {
            if run.is_empty() {
                if let Some(v) = vowel {
                    out.push(A_CHEN);
                    out.push_str(v);
                }
            } else {
                emit_root_run(&run, vowel, out, diags);
            }
        } else {
            // Suffixes, except that the consonants before a vowel start a new
            // unit: the longest standard stack ending at the vowel is its
            // root ("ngo'i" -> ngo + 'i, "masti" -> ma + sti).
            let mut split = run.len();
            if vowel.is_some() {
                split = run.len().saturating_sub(1);
                for k in 0..run.len() {
                    let tail = &run[k..];
                    if tail.iter().all(|c| !c.forced && c.cons.len() == 1) {
                        let keys: Vec<&str> = tail.iter().map(|c| c.cons[0].0).collect();
                        if legal_stack(&keys) {
                            split = k;
                            break;
                        }
                    }
                }
            }
            for c in &run[..split] {
                emit_cluster(c, out);
            }
            if let Some(v) = vowel {
                let root: Vec<Cons> = run[split..].iter().map(|c| c.cons[0]).collect();
                if run[split..].iter().all(|c| c.cons.len() == 1) {
                    emit_stack(&root, out);
                } else {
                    for c in &run[split..] {
                        emit_cluster(c, out);
                    }
                }
                out.push_str(v);
            }
        }
        first = false;

        let mut previous = None;
        while let Some(Tok {
            item: Item::Mark(m),
            start,
            end,
        }) = toks.get(i)
        {
            if !have_base {
                diags.push(Diagnostic::new(
                    Code::MarkWithoutBase,
                    *start..*end,
                    "this mark has no letter or vowel to attach to".to_string(),
                ));
            }
            if previous == Some(*m) {
                diags.push(Diagnostic::new(
                    Code::DuplicateMark,
                    *start..*end,
                    "the same mark is repeated; both are kept".to_string(),
                ));
            }
            previous = Some(*m);
            out.push(*m);
            i += 1;
        }
    }
}

/// Output choices.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Options {
    /// Emit the precomposed code points that Unicode only keeps for
    /// compatibility (for example U+0F43 for gha and U+0F76 for ra + reversed
    /// i). The default is the normalised (NFC) decomposed form.
    pub precomposed: bool,
}

/// Decomposed sequence to its precomposed code point, longest first.
const PRECOMPOSED: &[(&str, char)] = &[
    ("\u{0F40}\u{0FB5}", '\u{0F69}'),
    ("\u{0F42}\u{0FB7}", '\u{0F43}'),
    ("\u{0F4C}\u{0FB7}", '\u{0F4D}'),
    ("\u{0F51}\u{0FB7}", '\u{0F52}'),
    ("\u{0F56}\u{0FB7}", '\u{0F57}'),
    ("\u{0F5B}\u{0FB7}", '\u{0F5C}'),
    ("\u{0F90}\u{0FB5}", '\u{0FB9}'),
    ("\u{0F92}\u{0FB7}", '\u{0F93}'),
    ("\u{0F9C}\u{0FB7}", '\u{0F9D}'),
    ("\u{0FA1}\u{0FB7}", '\u{0FA2}'),
    ("\u{0FA6}\u{0FB7}", '\u{0FA7}'),
    ("\u{0FAB}\u{0FB7}", '\u{0FAC}'),
    ("\u{0F71}\u{0F72}", '\u{0F73}'),
    ("\u{0F71}\u{0F74}", '\u{0F75}'),
    ("\u{0F71}\u{0F80}", '\u{0F81}'),
    ("\u{0FB2}\u{0F80}", '\u{0F76}'),
    ("\u{0FB3}\u{0F80}", '\u{0F78}'),
];

/// Canonical combining class of the Tibetan marks, as in the Unicode
/// Character Database.
fn combining_class(c: char) -> u8 {
    match c {
        '\u{0F84}' => 9,
        '\u{0F71}' => 129,
        '\u{0F72}' | '\u{0F7A}'..='\u{0F7D}' | '\u{0F80}' => 130,
        '\u{0F74}' => 132,
        '\u{0F39}' => 216,
        '\u{0F18}' | '\u{0F19}' | '\u{0F35}' | '\u{0F37}' | '\u{0FC6}' => 220,
        '\u{0F82}' | '\u{0F83}' | '\u{0F86}' | '\u{0F87}' => 230,
        _ => 0,
    }
}

/// Reorders runs of combining marks into canonical order, so the output is
/// stable under NFC no matter in which order the marks were typed.
fn canonical_order(text: &str) -> String {
    let mut chars: Vec<char> = text.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if combining_class(chars[i]) == 0 {
            i += 1;
            continue;
        }
        let mut j = i;
        while j < chars.len() && combining_class(chars[j]) > 0 {
            j += 1;
        }
        chars[i..j].sort_by_key(|&c| combining_class(c));
        i = j;
    }
    chars.into_iter().collect()
}

fn compose(text: &str) -> String {
    let mut out = text.to_string();
    // "\u{0FB2}\u{0F71}\u{0F80}" (ra + long reversed i) must not turn into
    // U+0F76 + U+0F71, so the long vowel is composed first.
    for (from, to) in PRECOMPOSED
        .iter()
        .filter(|(f, _)| f.ends_with('\u{0F80}') && f.starts_with('\u{0F71}'))
    {
        out = out.replace(from, &to.to_string());
    }
    for (from, to) in PRECOMPOSED {
        out = out.replace(from, &to.to_string());
    }
    out
}

pub fn ewts_to_unicode(input: &str) -> String {
    ewts_to_unicode_with(input, Options::default())
}

pub fn ewts_to_unicode_with(input: &str, options: Options) -> String {
    convert(input, options).text
}

fn flush_unit(
    toks: &mut Vec<Tok>,
    out: &mut String,
    diags: &mut Vec<Diagnostic>,
    options: Options,
    floor: usize,
) {
    let mut syllable = String::new();
    convert_syllable(toks, &mut syllable, diags);
    toks.clear();
    if options.precomposed {
        syllable = compose(&canonical_order(&syllable));
    }

    // A run of combining marks can straddle the join between what is already
    // written and this unit ("Th~M`" then ".X"), so sort it as one run. Text
    // before `floor` was typed literally and is never reordered.
    let mut start = out.len();
    for (idx, c) in out[floor..].char_indices().rev() {
        if combining_class(c) == 0 {
            break;
        }
        start = floor + idx;
    }
    let lead = syllable
        .char_indices()
        .find(|&(_, c)| combining_class(c) == 0)
        .map_or(syllable.len(), |(i, _)| i);
    let mut run = out[start..].to_string();
    run.push_str(&syllable[..lead]);
    out.truncate(start);
    out.push_str(&canonical_order(&run));
    let rest = &syllable[lead..];
    out.push_str(&if options.precomposed {
        rest.to_string()
    } else {
        canonical_order(rest)
    });
}

/// Converts EWTS to Unicode and reports what was unusual about the input.
///
/// Diagnostics are advisory: the text is always produced, and unrecognised
/// input is passed through rather than dropped. Spans are UTF-8 byte offsets
/// into `input`.
pub fn convert(input: &str, options: Options) -> Conversion {
    let chars: Vec<char> = input.chars().collect();
    let n = chars.len();
    let mut offsets = Vec::with_capacity(n + 1);
    let mut byte = 0;
    for c in &chars {
        offsets.push(byte);
        byte += c.len_utf8();
    }
    offsets.push(byte);

    let mut out = String::new();
    let mut diags: Vec<Diagnostic> = Vec::new();
    let mut toks: Vec<Tok> = Vec::new();
    let mut i = 0;

    // Text that was typed literally (brackets, escapes, passthrough) lies
    // before `protected` and is never reordered. Anything that grew `out`
    // since the last flush was not produced by a flush.
    let mut protected = 0;
    let mut generated_end = 0;
    macro_rules! flush {
        () => {{
            if out.len() > generated_end {
                protected = out.len();
            }
            flush_unit(&mut toks, &mut out, &mut diags, options, protected);
            #[allow(unused_assignments)]
            {
                generated_end = out.len();
            }
        }};
    }

    // Diagnostics are built with `char` spans and converted at the end.
    macro_rules! note {
        ($code:expr, $range:expr, $msg:expr) => {
            diags.push(Diagnostic::new($code, $range, $msg))
        };
    }

    while i < n {
        let c = chars[i];

        if c == '+' {
            let next =
                lex_consonant(&chars[i + 1..]).or_else(|| lex_subjoined_only(&chars[i + 1..]));
            let prev_is_cons = matches!(
                toks.last(),
                Some(Tok {
                    item: Item::Cons(_),
                    ..
                })
            );
            // "ka+ya": an explicit a does not end the stack.
            let prev_is_a = matches!(
                toks.last(),
                Some(Tok {
                    item: Item::Vowel(""),
                    ..
                })
            ) && matches!(
                toks.len().checked_sub(2).and_then(|k| toks.get(k)),
                Some(Tok {
                    item: Item::Cons(_),
                    ..
                })
            );
            if let (Some((cons, len)), true) = (next, prev_is_cons || prev_is_a) {
                if prev_is_a {
                    toks.pop();
                }
                let tok = toks.last_mut().unwrap();
                if let Item::Cons(cl) = &mut tok.item {
                    cl.cons.push(cons);
                    cl.forced = true;
                    cl.end = i + 1 + len;
                }
                tok.end = i + 1 + len;
                i += 1 + len;
                continue;
            }
            flush!();
            out.push('+');
            if i + 1 >= n {
                note!(
                    Code::DanglingPlus,
                    i..i + 1,
                    "\"+\" is waiting for a consonant to join".to_string()
                );
            } else {
                note!(
                    Code::StrayPlus,
                    i..i + 1,
                    "\"+\" must sit between two consonants".to_string()
                );
            }
            i += 1;
            continue;
        }

        // "." keeps stacks apart ("g.ya"); anywhere else it is just a dot.
        if c == '.' && !toks.is_empty() && lex(&chars[i + 1..]).is_some() {
            flush!();
            i += 1;
            continue;
        }

        // Half numbers: -1 .. -9, then -0. Tried before `-` could be anything else.
        if c == '-' {
            if let Some(d) = chars.get(i + 1).and_then(|d| d.to_digit(10)) {
                flush!();
                out.push(char::from_u32(0x0F2A + (d + 9) % 10).unwrap());
                i += 2;
                continue;
            }
        }

        if toks.is_empty() && chars[i..].starts_with(&['o', 'M']) {
            out.push('\u{0F00}');
            i += 2;
            continue;
        }

        if let Some((mut item, len)) = lex(&chars[i..]) {
            if let Item::Cons(cl) = &mut item {
                cl.start = i;
                cl.end = i + len;
            }
            toks.push(Tok {
                item,
                start: i,
                end: i + len,
            });
            i += len;
            continue;
        }

        flush!();
        match c {
            ' ' => {
                let after_shad = matches!(out.chars().last(), Some(SHAD | NYIS_SHAD));
                out.push(if after_shad { ' ' } else { TSHEG });
            }
            '_' => out.push(' '),
            '/' => {
                if chars.get(i + 1) == Some(&'/') {
                    out.push(NYIS_SHAD);
                    i += 1;
                } else {
                    out.push(SHAD);
                }
            }
            '*' => out.push('\u{0F0C}'),
            ';' => out.push('\u{0F0F}'),
            '|' => out.push('\u{0F11}'),
            '!' => out.push('\u{0F08}'),
            ':' => out.push('\u{0F14}'),
            '=' => out.push('\u{0F34}'),
            '@' => out.push('\u{0F04}'),
            '#' => out.push('\u{0F05}'),
            '$' => out.push('\u{0F06}'),
            '%' => out.push('\u{0F07}'),
            '<' => out.push('\u{0F3A}'),
            '>' => out.push('\u{0F3B}'),
            '(' => out.push('\u{0F3C}'),
            ')' => out.push('\u{0F3D}'),
            '0'..='9' => out.push(char::from_u32(0x0F20 + (c as u32 - '0' as u32)).unwrap()),
            '~' => {
                out.push('~');
                if i + 1 >= n {
                    note!(
                        Code::IncompleteTilde,
                        i..i + 1,
                        "\"~\" may be the start of \"~M\" or \"~X\"".to_string()
                    );
                } else {
                    note!(
                        Code::StrayTilde,
                        i..i + 1,
                        "\"~\" is only meaningful as \"~M\", \"~M`\" or \"~X\"".to_string()
                    );
                }
            }
            '[' => {
                let end = chars[i + 1..].iter().position(|&c| c == ']');
                let stop = end.map_or(n, |e| i + 1 + e);
                out.extend(&chars[i + 1..stop]);
                if end.is_none() {
                    note!(
                        Code::UnterminatedLiteral,
                        i..n,
                        "\"[\" has no closing \"]\"; the rest is kept as plain text".to_string()
                    );
                }
                i = stop + 1;
                continue;
            }
            '\\' => {
                let digits = match chars.get(i + 1) {
                    Some('u') => 4,
                    Some('U') => 8,
                    Some(&other) => {
                        out.push(other);
                        i += 2;
                        continue;
                    }
                    None => {
                        out.push('\\');
                        note!(
                            Code::IncompleteEscape,
                            i..i + 1,
                            "\"\\\" is waiting for the character it escapes".to_string()
                        );
                        i += 1;
                        continue;
                    }
                };
                let hex: String = chars[i + 2..]
                    .iter()
                    .take_while(|c| c.is_ascii_hexdigit())
                    .take(digits)
                    .collect();
                let consumed = 2 + hex.len();
                if hex.len() == digits {
                    match u32::from_str_radix(&hex, 16).ok().and_then(char::from_u32) {
                        Some(ch) => {
                            if let Some((from, _)) = PRECOMPOSED.iter().find(|(_, to)| *to == ch) {
                                let parts: Vec<String> = from
                                    .chars()
                                    .map(|c| format!("U+{:04X}", c as u32))
                                    .collect();
                                note!(
                                    Code::NonCanonicalEscape,
                                    i..i + consumed,
                                    format!(
                                        "U+{:04X} is not in NFC; its NFC form is {}",
                                        ch as u32,
                                        parts.join(" ")
                                    )
                                );
                            }
                            out.push(ch);
                        }
                        None => {
                            out.extend(&chars[i..i + consumed]);
                            note!(
                                Code::InvalidEscape,
                                i..i + consumed,
                                format!("U+{hex} is not a Unicode scalar value")
                            );
                        }
                    }
                } else {
                    out.extend(&chars[i..i + consumed]);
                    if i + consumed >= n {
                        note!(
                            Code::IncompleteEscape,
                            i..n,
                            format!(
                                "expected {digits} hexadecimal digits after \"\\{}\"",
                                chars[i + 1]
                            )
                        );
                    } else {
                        note!(
                            Code::InvalidEscape,
                            i..i + consumed,
                            format!(
                                "expected {digits} hexadecimal digits after \"\\{}\"",
                                chars[i + 1]
                            )
                        );
                    }
                }
                i += consumed;
                continue;
            }
            '.' | '-' => out.push(c),
            other => {
                out.push(other);
                if other.is_ascii_alphabetic() {
                    note!(
                        Code::UnsupportedCharacter,
                        i..i + 1,
                        format!("\"{other}\" is not an EWTS letter; it is kept as written")
                    );
                }
            }
        }
        i += 1;
    }
    flush!();

    for d in &mut diags {
        d.span = offsets[d.span.start]..offsets[d.span.end.min(n)];
    }
    diags.sort_by_key(|d| (d.span.start, d.span.end));
    Conversion {
        text: out,
        diagnostics: diags,
    }
}

#[cfg(test)]
mod tests {
    use super::ewts_to_unicode as c;

    #[test]
    fn simple_syllables() {
        assert_eq!(c("bod"), "བོད");
        assert_eq!(c("ka"), "ཀ");
        assert_eq!(c("nga"), "ང");
        assert_eq!(c("a"), "ཨ");
        assert_eq!(c("o"), "ཨོ");
    }

    #[test]
    fn space_is_tsheg() {
        assert_eq!(c("bod skad"), "བོད་སྐད");
        assert_eq!(c("bkra shis bde legs"), "བཀྲ་ཤིས་བདེ་ལེགས");
    }

    #[test]
    fn prefixes_and_stacks() {
        assert_eq!(c("bsgrubs"), "བསྒྲུབས");
        assert_eq!(c("rgyal"), "རྒྱལ");
        assert_eq!(c("brda"), "བརྡ");
        assert_eq!(c("gsum"), "གསུམ");
        assert_eq!(c("dbyar"), "དབྱར");
        assert_eq!(c("bskyod"), "བསྐྱོད");
        assert_eq!(c("sprul sku"), "སྤྲུལ་སྐུ");
        assert_eq!(c("srung"), "སྲུང");
        assert_eq!(c("slob"), "སློབ");
        assert_eq!(c("lha sa"), "ལྷ་ས");
        assert_eq!(c("zhwa"), "ཞྭ");
        assert_eq!(c("mthong"), "མཐོང");
        assert_eq!(c("'jam dpal"), "འཇམ་དཔལ");
        assert_eq!(c("gzhis ka rtse"), "གཞིས་ཀ་རྩེ");
    }

    #[test]
    fn suffix_with_following_vowel() {
        assert_eq!(c("dga'"), "དགའ");
        assert_eq!(c("ngo'i"), "ངོའི");
    }

    #[test]
    fn vowels_and_marks() {
        assert_eq!(c("kI"), "ཀ\u{0F71}\u{0F72}");
        assert_eq!(c("ke"), "ཀེ");
        assert_eq!(c("kM"), "ཀཾ");
        assert_eq!(c("k-i"), "ཀྀ");
    }

    #[test]
    fn explicit_stacking() {
        assert_eq!(c("k+Sha"), "ཀྵ");
        assert_eq!(c("g+ra"), "གྲ");
    }

    #[test]
    fn punctuation_and_digits() {
        assert_eq!(c("/"), "།");
        assert_eq!(c("//"), "༎");
        assert_eq!(c("bod/ bod"), "བོད། བོད");
        assert_eq!(c("0123"), "༠༡༢༣");
        assert_eq!(c("a_b"), "ཨ བ");
    }

    #[test]
    fn extra_stacks_and_ambiguous_prefixes() {
        assert_eq!(c("shr"), "\u{0F64}\u{0FB2}");
        assert_eq!(c("snr"), "\u{0F66}\u{0FA3}\u{0FB2}");
        assert_eq!(c("phyw"), "\u{0F55}\u{0FB1}\u{0FAD}");
        // b is a prefix before ra-mgo + la
        assert_eq!(c("brla"), "\u{0F56}\u{0F62}\u{0FB3}");
    }

    #[test]
    fn sanskrit_and_extras() {
        assert_eq!(c("gha"), "\u{0F42}\u{0FB7}");
        assert_eq!(c("fa"), "\u{0F55}\u{0F39}");
        assert_eq!(c("Ra"), "\u{0F6A}");
        assert_eq!(c("oM"), "\u{0F00}");
        assert_eq!(c("kuo"), "\u{0F40}\u{0F7C}\u{0F74}");
        assert_eq!(c("k.ya"), "\u{0F40}\u{0F61}");
    }
}
