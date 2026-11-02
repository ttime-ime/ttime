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

/// (EWTS key, code point), longest keys first so greedy matching works.
const CONSONANTS: &[(&str, char)] = &[
    ("tsh", '\u{0F5A}'),
    ("ts", '\u{0F59}'),
    ("dz", '\u{0F5B}'),
    ("zh", '\u{0F5E}'),
    ("sh", '\u{0F64}'),
    ("kh", '\u{0F41}'),
    ("ng", '\u{0F44}'),
    ("ch", '\u{0F46}'),
    ("ny", '\u{0F49}'),
    ("th", '\u{0F50}'),
    ("ph", '\u{0F55}'),
    ("Th", '\u{0F4B}'),
    ("Sh", '\u{0F65}'),
    ("k", '\u{0F40}'),
    ("g", '\u{0F42}'),
    ("c", '\u{0F45}'),
    ("j", '\u{0F47}'),
    ("t", '\u{0F4F}'),
    ("d", '\u{0F51}'),
    ("n", '\u{0F53}'),
    ("p", '\u{0F54}'),
    ("b", '\u{0F56}'),
    ("m", '\u{0F58}'),
    ("w", '\u{0F5D}'),
    ("z", '\u{0F5F}'),
    ("'", '\u{0F60}'),
    ("y", '\u{0F61}'),
    ("r", '\u{0F62}'),
    ("l", '\u{0F63}'),
    ("s", '\u{0F66}'),
    ("h", '\u{0F67}'),
    ("T", '\u{0F4A}'),
    ("D", '\u{0F4C}'),
    ("N", '\u{0F4E}'),
];

/// Longest keys first. `a` outputs nothing: it is the inherent vowel.
const VOWELS: &[(&str, &str)] = &[
    ("-I", "\u{0F71}\u{0F80}"),
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

const MARKS: &[(char, char)] = &[('M', '\u{0F7E}'), ('H', '\u{0F7F}')];

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
        "r" => &["k", "kh", "g", "t", "th", "d", "p", "ph", "b", "m", "s", "h"],
        "l" => &["k", "g", "b", "z", "r", "s"],
        "w" => &[
            "k", "kh", "g", "c", "ny", "t", "d", "ts", "tsh", "zh", "z", "r", "l", "sh", "s", "h",
        ],
        _ => return false,
    };
    roots.contains(&root)
}

fn subscripts_ok(keys: &[&str]) -> bool {
    keys.windows(2).all(|w| subscript_ok(w[0], w[1]))
}

/// Is this consonant sequence a legal Tibetan stack, so it can be joined
/// without an explicit `+`?
fn legal_stack(keys: &[&str]) -> bool {
    match keys.len() {
        0 => false,
        1 => true,
        _ => (superscript_ok(keys[0], keys[1]) && subscripts_ok(&keys[1..])) || subscripts_ok(keys),
    }
}

#[derive(Debug, Clone)]
struct Cluster {
    cons: Vec<(&'static str, char)>,
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

fn lex_consonant(chars: &[char]) -> Option<((&'static str, char), usize)> {
    CONSONANTS.iter().find_map(|&(key, cp)| {
        let n = key.chars().count();
        let matches = chars.len() >= n && key.chars().zip(chars).all(|(a, &b)| a == b);
        matches.then_some(((key, cp), n))
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
    if let Some(&(_, cp)) = MARKS.iter().find(|(k, _)| *k == chars[0]) {
        return Some((Item::Mark(cp), 1));
    }
    if chars[0] == '-' {
        return Some((Item::Sep, 1));
    }
    None
}

fn subjoined(cp: char) -> char {
    char::from_u32(cp as u32 + SUBJOINED_OFFSET).unwrap_or(cp)
}

fn emit_stack(cons: &[(&'static str, char)], out: &mut String) {
    for (i, &(_, cp)) in cons.iter().enumerate() {
        out.push(if i == 0 { cp } else { subjoined(cp) });
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
    let stack: Vec<(&'static str, char)> = run[start..]
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
}
