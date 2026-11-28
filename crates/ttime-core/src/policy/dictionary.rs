//! Dictionary lookup term rules and Steinert site URL.

/// Christian Steinert's Tibetan-English dictionary site. Nothing from it is bundled.
pub const SITE: &str = "https://dictionary.christian-steinert.de/";

/// The site's search page for a Tibetan term (Unicode in the URL).
pub fn url_for(term: &str) -> Option<String> {
    let t = term.trim();
    if t.is_empty() {
        return None;
    }
    let e = percent_encode(t);
    Some(format!("{SITE}#/search/tib/{e}?activeTerm={e}"))
}

/// The term to look up: the selection if there is one (trimmed of spaces and
/// trailing marks), else the syllable just before the caret.
pub fn term(selection: Option<&str>, before: Option<&str>) -> String {
    if let Some(s) = selection {
        let mut scalars: Vec<char> = s.chars().collect();
        while scalars.last().copied().is_some_and(is_separator) {
            scalars.pop();
        }
        while scalars.first().copied().is_some_and(|c| c.is_whitespace()) {
            scalars.remove(0);
        }
        if !scalars.is_empty() {
            return scalars.into_iter().collect();
        }
    }
    let Some(b) = before else {
        return String::new();
    };
    let mut scalars: Vec<char> = b.chars().collect();
    while scalars.last().copied().is_some_and(is_separator) {
        scalars.pop();
    }
    let mut out: Vec<char> = Vec::new();
    while scalars.last().copied().is_some_and(is_tibetan_letter) {
        out.insert(0, scalars.pop().unwrap());
    }
    out.into_iter().collect()
}

fn is_tibetan_letter(c: char) -> bool {
    (0x0F40..=0x0FBC).contains(&(c as u32))
}

fn is_separator(c: char) -> bool {
    c.is_whitespace() || (0x0F0B..=0x0F14).contains(&(c as u32))
}

/// Percent-encode like Swift `addingPercentEncoding(withAllowedCharacters:)`
/// with `urlPathAllowed` minus `/?#&=+%`.
fn percent_encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        if is_allowed(b) {
            out.push(b as char);
        } else {
            use std::fmt::Write;
            let _ = write!(out, "%{b:02X}");
        }
    }
    out
}

fn is_allowed(b: u8) -> bool {
    // Reject explicitly removed characters and anything that is not in a
    // typical URL path allowed set.
    if matches!(b, b'/' | b'?' | b'#' | b'&' | b'=' | b'+' | b'%') {
        return false;
    }
    b.is_ascii_alphanumeric()
        || matches!(
            b,
            b'-' | b'.'
                | b'_'
                | b'~'
                | b'!'
                | b'$'
                | b'\''
                | b'('
                | b')'
                | b'*'
                | b','
                | b';'
                | b':'
                | b'@'
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn term_from_selection_or_caret() {
        assert_eq!(term(None, Some("བོད་སྐད་")), "སྐད");
        assert_eq!(term(None, Some("བོད་སྐད")), "སྐད");
        assert_eq!(term(None, Some("བོད་སྐད། ")), "སྐད");
        assert_eq!(term(None, Some("hello")), "");
        assert_eq!(term(Some("བོད་སྐད་"), Some("x")), "བོད་སྐད");
        assert_eq!(term(Some("  "), Some("བོད་")), "བོད");
        assert_eq!(term(None, None), "");
    }

    #[test]
    fn search_url() {
        assert_eq!(
            url_for("སྐད").as_deref(),
            Some(
                "https://dictionary.christian-steinert.de/#/search/tib/%E0%BD%A6%E0%BE%90%E0%BD%91?activeTerm=%E0%BD%A6%E0%BE%90%E0%BD%91"
            )
        );
        assert_eq!(
            url_for("a b&c#").as_deref(),
            Some(
                "https://dictionary.christian-steinert.de/#/search/tib/a%20b%26c%23?activeTerm=a%20b%26c%23"
            )
        );
        assert_eq!(url_for("  "), None);
    }
}
