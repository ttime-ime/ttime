//! Dead keys for the IAST letters used with Sanskrit, typed in Latin mode.
//!
//! `;` followed by a key gives the lower-case letter; `:` (Shift+`;` on most
//! layouts) gives the capital. Neither character normally comes directly
//! before a letter in English, so they are free to act as triggers. The second
//! key is case-sensitive: `r` is ṛ and `R` is ṝ, `n` is ṅ and `N` is ṇ.

pub const LOWER_TRIGGER: char = ';';
pub const UPPER_TRIGGER: char = ':';

/// Second key, lower-case letter, capital.
const TABLE: [(char, char, char); 16] = [
    ('a', 'ā', 'Ā'),
    ('i', 'ī', 'Ī'),
    ('u', 'ū', 'Ū'),
    ('r', 'ṛ', 'Ṛ'),
    ('R', 'ṝ', 'Ṝ'),
    ('l', 'ḷ', 'Ḷ'),
    ('L', 'ḹ', 'Ḹ'),
    ('m', 'ṃ', 'Ṃ'),
    ('h', 'ḥ', 'Ḥ'),
    ('n', 'ṅ', 'Ṅ'),
    ('N', 'ṇ', 'Ṇ'),
    ('y', 'ñ', 'Ñ'),
    ('t', 'ṭ', 'Ṭ'),
    ('d', 'ḍ', 'Ḍ'),
    ('s', 'ś', 'Ś'),
    ('S', 'ṣ', 'Ṣ'),
];

pub fn is_trigger(c: char) -> bool {
    c == LOWER_TRIGGER || c == UPPER_TRIGGER
}

/// The letter for `trigger` followed by `key`, if there is one.
pub fn compose(trigger: char, key: char) -> Option<char> {
    let (_, lower, upper) = TABLE.iter().copied().find(|(k, _, _)| *k == key)?;
    match trigger {
        LOWER_TRIGGER => Some(lower),
        UPPER_TRIGGER => Some(upper),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn results_are_the_precomposed_code_points() {
        // Guards against a combining sequence slipping in through an editor.
        let lower: Vec<u32> = TABLE.iter().map(|t| t.1 as u32).collect();
        assert_eq!(
            lower,
            [
                0x101, 0x12B, 0x16B, 0x1E5B, 0x1E5D, 0x1E37, 0x1E39, 0x1E43, 0x1E25, 0x1E45, 0x1E47, 0xF1,
                0x1E6D, 0x1E0D, 0x15B, 0x1E63
            ]
        );
        let upper: Vec<u32> = TABLE.iter().map(|t| t.2 as u32).collect();
        assert_eq!(
            upper,
            [
                0x100, 0x12A, 0x16A, 0x1E5A, 0x1E5C, 0x1E36, 0x1E38, 0x1E42, 0x1E24, 0x1E44, 0x1E46, 0xD1,
                0x1E6C, 0x1E0C, 0x15A, 0x1E62
            ]
        );
    }

    #[test]
    fn keys_are_unique_and_capitals_follow_lower_case() {
        for (i, (k, lower, upper)) in TABLE.iter().enumerate() {
            assert!(TABLE[i + 1..].iter().all(|(o, _, _)| o != k), "duplicate key {k}");
            assert_eq!(lower.to_uppercase().to_string(), upper.to_string());
        }
    }

    #[test]
    fn the_whole_set_is_reachable() {
        let got: String = "aiurRlLmhnNytdsS".chars().filter_map(|k| compose(';', k)).collect();
        assert_eq!(got, "āīūṛṝḷḹṃḥṅṇñṭḍśṣ");
    }
}
