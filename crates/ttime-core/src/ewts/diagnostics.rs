//! Structured diagnostics for EWTS conversion.
//!
//! Diagnostics never change the converted text and are never fatal: a
//! scholar can always type unusual or malformed text on purpose. They exist so
//! an interface can underline the affected input and explain it.
//!
//! Spans are half-open ranges of **UTF-8 byte offsets into the input string**
//! passed to the converter. They always fall on `char` boundaries, so they can
//! be used directly to slice the input.

use std::ops::Range;

/// What kind of problem was found.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Category {
    /// Well-formed EWTS was expected but the sequence is not.
    Invalid,
    /// The input ends where more input could still make it valid.
    Incomplete,
    /// A character or construct EWTS does not define or T-Time does not
    /// implement.
    Unsupported,
    /// The input has more than one reasonable reading; T-Time chose one.
    Ambiguous,
    /// The text is well formed but has Unicode normalization consequences.
    Unicode,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Severity {
    /// Worth knowing; nothing is likely wrong.
    Info,
    /// Probably not what the writer meant, but the output is still produced.
    Warning,
}

/// Machine-readable identifier. [`Code::as_str`] gives the stable string form;
/// strings never change once released, and new variants may be added.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Code {
    /// `+` that cannot join the consonants around it.
    StrayPlus,
    /// `+` at the very end of the input.
    DanglingPlus,
    /// A combining mark (`M`, `H`, ...) with no letter or vowel to attach to.
    MarkWithoutBase,
    /// The same mark twice in a row.
    DuplicateMark,
    /// An ASCII letter that is not part of any EWTS token.
    UnsupportedCharacter,
    /// `~` that does not start `~M` or `~X`.
    StrayTilde,
    /// `~` at the very end of the input.
    IncompleteTilde,
    /// `[` without a closing `]`.
    UnterminatedLiteral,
    /// `\`, `\u` or `\U` cut short by the end of the input.
    IncompleteEscape,
    /// `\u` or `\U` that is not followed by enough hexadecimal digits, or
    /// that names no valid code point.
    InvalidEscape,
    /// An escape names a precomposed Tibetan character that NFC rewrites.
    NonCanonicalEscape,
    /// A prefix letter plus ya, ra, la or wa read as a stack (`gya`); the
    /// prefix reading needs `.` (`g.ya`).
    AmbiguousPrefixStack,
    /// An `a` that follows a vowel or mark and adds nothing, so it is not in
    /// the output. Reported in diplomatic mode only.
    DroppedInput,
    /// `oM` written as the single character U+0F00; some converters write the
    /// letters instead. Reported in diplomatic mode only.
    OmSyllable,
    /// `X` or `~X` written as U+0F37 or U+0F35; some converters use U+0FBE.
    /// Reported in diplomatic mode only.
    XSign,
    /// An aspirated letter followed by y, r, l or w that is not a standard
    /// stack here (`ghr`); some converters stack it. Reported in diplomatic
    /// mode only.
    UnstackedSubjoin,
    /// (Unicode to EWTS) A Tibetan-block character, or a letter with its
    /// marks, that has no EWTS spelling; it is written as a `\uXXXX` escape.
    ReverseUnsupportedCodePoint,
    /// (Unicode to EWTS) No vowel sign marks the root letter of a syllable,
    /// so the spelling assumes one.
    ReverseAmbiguousRoot,
    /// (Unicode to EWTS) The input was not in canonical order or used a
    /// precomposed character, so the result is only canonically equivalent.
    ReverseNonCanonicalInput,
}

impl Code {
    /// Every code, for tooling and tests.
    pub const ALL: [Code; 19] = [
        Code::StrayPlus,
        Code::DanglingPlus,
        Code::MarkWithoutBase,
        Code::DuplicateMark,
        Code::UnsupportedCharacter,
        Code::StrayTilde,
        Code::IncompleteTilde,
        Code::UnterminatedLiteral,
        Code::IncompleteEscape,
        Code::InvalidEscape,
        Code::NonCanonicalEscape,
        Code::AmbiguousPrefixStack,
        Code::DroppedInput,
        Code::OmSyllable,
        Code::XSign,
        Code::UnstackedSubjoin,
        Code::ReverseUnsupportedCodePoint,
        Code::ReverseAmbiguousRoot,
        Code::ReverseNonCanonicalInput,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            Code::StrayPlus => "ewts.stray-plus",
            Code::DanglingPlus => "ewts.dangling-plus",
            Code::MarkWithoutBase => "ewts.mark-without-base",
            Code::DuplicateMark => "ewts.duplicate-mark",
            Code::UnsupportedCharacter => "ewts.unsupported-character",
            Code::StrayTilde => "ewts.stray-tilde",
            Code::IncompleteTilde => "ewts.incomplete-tilde",
            Code::UnterminatedLiteral => "ewts.unterminated-literal",
            Code::IncompleteEscape => "ewts.incomplete-escape",
            Code::InvalidEscape => "ewts.invalid-escape",
            Code::NonCanonicalEscape => "ewts.non-canonical-escape",
            Code::AmbiguousPrefixStack => "ewts.ambiguous-prefix-stack",
            Code::DroppedInput => "ewts.dropped-input",
            Code::OmSyllable => "ewts.om-syllable",
            Code::XSign => "ewts.x-sign",
            Code::UnstackedSubjoin => "ewts.unstacked-subjoin",
            Code::ReverseUnsupportedCodePoint => "reverse.unsupported-code-point",
            Code::ReverseAmbiguousRoot => "reverse.ambiguous-root",
            Code::ReverseNonCanonicalInput => "reverse.non-canonical-input",
        }
    }

    pub fn category(self) -> Category {
        match self {
            Code::StrayPlus
            | Code::MarkWithoutBase
            | Code::DuplicateMark
            | Code::StrayTilde
            | Code::InvalidEscape
            | Code::DroppedInput => Category::Invalid,
            Code::DanglingPlus
            | Code::IncompleteTilde
            | Code::UnterminatedLiteral
            | Code::IncompleteEscape => Category::Incomplete,
            Code::UnsupportedCharacter | Code::ReverseUnsupportedCodePoint => Category::Unsupported,
            Code::AmbiguousPrefixStack
            | Code::OmSyllable
            | Code::XSign
            | Code::UnstackedSubjoin
            | Code::ReverseAmbiguousRoot => Category::Ambiguous,
            Code::NonCanonicalEscape | Code::ReverseNonCanonicalInput => Category::Unicode,
        }
    }

    pub fn severity(self) -> Severity {
        match self {
            Code::AmbiguousPrefixStack
            | Code::OmSyllable
            | Code::XSign
            | Code::UnstackedSubjoin
            | Code::ReverseAmbiguousRoot
            | Code::ReverseNonCanonicalInput => Severity::Info,
            _ => Severity::Warning,
        }
    }
}

impl Code {
    /// Codes that report a choice or a silent change the converter makes.
    /// They are produced only in diplomatic mode, where they are Warnings.
    pub fn is_diplomatic_only(self) -> bool {
        matches!(
            self,
            Code::DroppedInput | Code::OmSyllable | Code::XSign | Code::UnstackedSubjoin
        )
    }

    /// Codes that diplomatic mode raises to Warning so that no choice the
    /// converter made goes unreported.
    pub fn is_diplomatic_warning(self) -> bool {
        self.is_diplomatic_only() || self == Code::AmbiguousPrefixStack
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Diagnostic {
    pub category: Category,
    pub severity: Severity,
    pub code: Code,
    /// UTF-8 byte offsets into the input, half-open.
    pub span: Range<usize>,
    pub message: String,
}

impl Diagnostic {
    pub(crate) fn new(code: Code, span: Range<usize>, message: String) -> Self {
        Self {
            category: code.category(),
            severity: code.severity(),
            code,
            span,
            message,
        }
    }
}

/// Converted text together with everything worth telling the writer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Conversion {
    pub text: String,
    pub diagnostics: Vec<Diagnostic>,
}
