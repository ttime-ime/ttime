//! EWTS (Extended Wylie Transliteration Scheme) to Tibetan Unicode.
//!
//! Supported: the thirty Tibetan consonants, Sanskrit retroflexes (`T Th D N
//! Sh`), the vowels `a i u e o A I U ai au -i -I`, `M` and `H`, explicit
//! stacking with `+`, implicit stacking by the legal-stack tables, digits and
//! basic punctuation. A space is a tsheg and `_` is a real space.

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

/// Stacks that the general rules reject but Tibetan uses.
const EXTRA_STACKS: &[&[&str]] = &[&["s", "n", "r"], &["ph", "y", "w"]];

/// Consonants that can sit on top of a root (ra-mgo, la-mgo, sa-mgo).
fn superscript_ok(sup: &str, root: &str) -> bool {
    let roots: &[&str] = match sup {
        "r" => &["k", "g", "ng", "j", "ny", "t", "d", "n", "b", "m", "ts", "dz"],
        "l" => &["k", "g", "ng", "c", "j", "t", "d", "p", "b", "h"],
        "s" => &["k", "g", "ng", "ny", "t", "d", "n", "p", "b", "m", "ts"],
        _ => return false,
    };
    roots.contains(&root)
}

/// Consonants that can be subjoined under `root` (ya-btags, ra-btags, ...).
fn subscript_ok(root: &str, sub: &str) -> bool {
    let roots: &[&str] = match sub {
        "y" => &["k", "kh", "g", "p", "ph", "b", "m"],
        "r" => &["k", "kh", "g", "t", "th", "d", "p", "ph", "b", "m", "sh", "s", "h"],
        "l" => &["k", "g", "b", "z", "r", "s"],
        "w" => &[
            "k", "kh", "g", "c", "ny", "t", "d", "ts", "tsh", "zh", "z", "r", "l", "sh", "s", "h",
        ],
        _ => return false,
    };
    roots.contains(&root)
}

/// `keys` is a root followed by subjoined letters, which must come in the
/// order ya, ra, wa, or be a lone la.
fn subscripts_ok(keys: &[&str]) -> bool {
    let rank = |s: &str| match s {
        "y" => Some(0),
        "r" => Some(1),
        "w" => Some(2),
        _ => None,
    };
    let subs = &keys[1..];
    subs.iter().all(|s| subscript_ok(keys[0], s))
        && subs
            .windows(2)
            .all(|w| matches!((rank(w[0]), rank(w[1])), (Some(a), Some(b)) if a < b))
}

/// Is this consonant sequence a legal Tibetan stack, so it can be joined
/// without an explicit `+`?
fn legal_stack(keys: &[&str]) -> bool {
    match keys.len() {
        0 => false,
        1 => true,
        _ if EXTRA_STACKS.contains(&keys) => true,
        _ => (superscript_ok(keys[0], keys[1]) && subscripts_ok(&keys[1..])) || subscripts_ok(keys),
    }
}

#[derive(Debug, Clone)]
struct Cluster {
    cons: Vec<Cons>,
    /// Joined with `+`; never merged with its neighbours.
    forced: bool,
}

#[derive(Debug, Clone)]
enum Item {
    Cons(Cluster),
    Vowel(&'static str),
    Mark(char),
    /// `-`: ends the current syllable without output.
    Sep,
}

fn lex_consonant(chars: &[char]) -> Option<(Cons, usize)> {
    CONSONANTS.iter().find_map(|&(key, cp, tail)| {
        let n = key.chars().count();
        let matches = chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b);
        matches.then_some(((key, cp, tail), n))
    })
}

fn lex(chars: &[char]) -> Option<(Item, usize)> {
    if let Some((key, out)) = VOWELS.iter().find(|(key, _)| {
        let n = key.chars().count();
        chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b)
    }) {
        return Some((Item::Vowel(out), key.chars().count()));
    }
    if let Some((c, n)) = lex_consonant(chars) {
        return Some((Item::Cons(Cluster { cons: vec![c], forced: false }), n));
    }
    if let Some(&(key, cp)) = MARKS.iter().find(|(key, _)| {
        let n = key.chars().count();
        chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b)
    }) {
        return Some((Item::Mark(cp), key.chars().count()));
    }
    if chars[0] == '-' {
        return Some((Item::Sep, 1));
    }
    None
}

fn subjoined(cp: char) -> char {
    char::from_u32(cp as u32 + SUBJOINED_OFFSET).unwrap_or(cp)
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
fn emit_root_run(run: &[&Cluster], vowel: Option<&str>, out: &mut String) {
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

fn convert_syllable(items: &[Item], out: &mut String) {
    let mut i = 0;
    let mut first = true;
    while i < items.len() {
        let mut run: Vec<&Cluster> = Vec::new();
        while let Some(Item::Cons(c)) = items.get(i) {
            run.push(c);
            i += 1;
        }
        let vowel = match items.get(i) {
            Some(Item::Vowel(v)) => {
                i += 1;
                Some(*v)
            }
            _ => None,
        };

        if first {
            if run.is_empty() {
                if let Some(v) = vowel {
                    out.push(A_CHEN);
                    out.push_str(v);
                }
            } else {
                emit_root_run(&run, vowel, out);
            }
        } else {
            // Suffixes, except that a consonant followed by a vowel starts a
            // new unit ("ngo'i" -> ngo + 'i).
            let (suffixes, root) = match (vowel, run.split_last()) {
                (Some(v), Some((last, rest))) => (rest, Some((*last, v))),
                _ => (&run[..], None),
            };
            for c in suffixes {
                emit_cluster(c, out);
            }
            match (root, vowel) {
                (Some((c, v)), _) => {
                    emit_cluster(c, out);
                    out.push_str(v);
                }
                (None, Some(v)) => out.push_str(v),
                _ => {}
            }
        }
        first = false;

        while let Some(item) = items.get(i) {
            match item {
                Item::Mark(m) => out.push(*m),
                Item::Sep => first = true,
                _ => break,
            }
            i += 1;
        }
    }
}

pub fn ewts_to_unicode(input: &str) -> String {
    let chars: Vec<char> = input.chars().collect();
    let mut out = String::new();
    let mut items: Vec<Item> = Vec::new();
    let mut i = 0;

    fn flush(items: &mut Vec<Item>, out: &mut String) {
        convert_syllable(items, out);
        items.clear();
    }

    while i < chars.len() {
        let c = chars[i];

        if c == '+' {
            if let (Some(Item::Cons(prev)), Some((cons, n))) =
                (items.last_mut(), lex_consonant(&chars[i + 1..]))
            {
                prev.cons.push(cons);
                prev.forced = true;
                i += 1 + n;
            } else {
                i += 1;
            }
            continue;
        }

        if items.is_empty() && chars[i..].starts_with(&['o', 'M']) {
            out.push('\u{0F00}');
            i += 2;
            continue;
        }

        if let Some((item, n)) = lex(&chars[i..]) {
            items.push(item);
            i += n;
            continue;
        }

        flush(&mut items, &mut out);
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
            '.' => {}
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
            other => out.push(other),
        }
        i += 1;
    }
    flush(&mut items, &mut out);
    out
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
