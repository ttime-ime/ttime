//! Key policy on top of [`Session`]. No UI dependencies.

use super::accent::AccentPalette;
use super::key::{KeyInput, Outcome};
use super::sanskrit::{SanskritLexicon, SanskritSuggester};
use crate::composition::Session;
use std::sync::Arc;

/// Key policy for an IME front end.
#[derive(Debug)]
pub struct Composer {
    session: Session,
    precomposed: bool,
    suggester: Option<SanskritSuggester>,
    accents: bool,
    palette: AccentPalette,
    palette_letter: String,
    ignore_repeats: Option<String>,
    /// With no suggester, a letter that has variants waits as marked text.
    pending: String,
}

impl Composer {
    pub fn new(precomposed: bool) -> Self {
        Self {
            session: Session::new(precomposed),
            precomposed,
            suggester: None,
            accents: false,
            palette: AccentPalette::default(),
            palette_letter: String::new(),
            ignore_repeats: None,
            pending: String::new(),
        }
    }

    pub fn precomposed(&self) -> bool {
        self.precomposed
    }

    /// Switches the output form. Anything being typed is dropped.
    pub fn set_precomposed(&mut self, on: bool) {
        if on == self.precomposed {
            return;
        }
        let latin = self.is_latin();
        self.precomposed = on;
        self.session = Session::new(on);
        if latin {
            self.session.set_latin(true);
        }
    }

    pub fn accents(&self) -> bool {
        self.accents
    }

    pub fn set_accents(&mut self, on: bool) {
        self.accents = on;
    }

    /// Sanskrit suggestions for Latin mode; `None` turns them off. The list is shared,
    /// so this is cheap; set it between words (it forgets the word being typed).
    pub fn set_lexicon(&mut self, lexicon: Option<Arc<SanskritLexicon>>) {
        self.suggester = lexicon.map(SanskritSuggester::new);
    }

    pub fn has_suggester(&self) -> bool {
        self.suggester.is_some()
    }

    pub fn suggestion_list(&self) -> Option<(Vec<String>, usize)> {
        let s = self.suggester.as_ref()?;
        if !self.is_latin() || s.shown().is_empty() {
            return None;
        }
        Some((s.shown(), s.selected()))
    }

    pub fn suggestion_buffer(&self) -> &str {
        self.suggester.as_ref().map(|s| s.buffer()).unwrap_or("")
    }

    pub fn accent_list(&self) -> Option<(Vec<String>, Option<usize>)> {
        if self.palette.is_open() {
            Some((self.palette.options().to_vec(), self.palette.selected()))
        } else {
            None
        }
    }

    fn close_palette(&mut self) {
        if self.palette.is_open() {
            self.ignore_repeats = Some(self.palette_letter.clone());
        }
        self.palette.close();
    }

    fn shown_text(&self) -> &str {
        if self.suggester.is_none() {
            &self.pending
        } else {
            ""
        }
    }

    fn held_letter(&self) -> String {
        if let Some(s) = &self.suggester {
            s.buffer()
                .chars()
                .last()
                .map(|c| c.to_string())
                .unwrap_or_default()
        } else {
            self.pending.clone()
        }
    }

    pub fn choose_suggestion(&mut self, index: usize) -> Outcome {
        if !self.is_latin() {
            return Outcome::default();
        }
        let Some(s) = self.suggester.as_mut() else {
            return Outcome::default();
        };
        if !s.select(index) {
            return Outcome::default();
        }
        let typed = s.buffer().to_string();
        let Some(word) = s.accept() else {
            return Outcome::default();
        };
        Outcome {
            insert: word,
            replacing: typed,
            handled: true,
            ..Outcome::default()
        }
    }

    pub fn choose_highlighted_accent(&mut self) -> Outcome {
        let Some(i) = self.palette.selected() else {
            return Outcome::default();
        };
        if !self.palette.is_open() {
            return Outcome::default();
        }
        let variant = self.palette.options()[i].clone();
        self.choose_accent_str(&variant)
    }

    pub fn choose_accent(&mut self, index: usize) -> Outcome {
        if !self.palette.is_open() || index >= self.palette.options().len() {
            return Outcome::default();
        }
        let variant = self.palette.options()[index].clone();
        self.choose_accent_str(&variant)
    }

    fn choose_accent_str(&mut self, variant: &str) -> Outcome {
        self.close_palette();
        if let Some(s) = self.suggester.as_mut() {
            let last = s
                .buffer()
                .chars()
                .last()
                .map(|c| c.to_string())
                .unwrap_or_default();
            s.replace_last(variant);
            Outcome {
                insert: variant.to_string(),
                replacing: last,
                handled: true,
                ..Outcome::default()
            }
        } else {
            self.pending.clear();
            Outcome {
                insert: variant.to_string(),
                marked: String::new(),
                handled: true,
                ..Outcome::default()
            }
        }
    }

    fn handle_accent(&mut self, key: &KeyInput, is_repeat: bool) -> Option<Outcome> {
        if !self.accents || !self.is_latin() {
            return None;
        }
        if !is_repeat {
            self.ignore_repeats = None;
        }
        if is_repeat {
            if let Some(ignored) = &self.ignore_repeats {
                if let KeyInput::Text(s) = key {
                    if s == ignored {
                        return Some(Outcome {
                            marked: self.shown_text().to_string(),
                            handled: true,
                            ..Outcome::default()
                        });
                    }
                }
            }
        }
        if self.palette.is_open() {
            match key {
                KeyInput::Text(s) => {
                    if is_repeat {
                        return Some(Outcome {
                            marked: self.shown_text().to_string(),
                            handled: true,
                            ..Outcome::default()
                        });
                    }
                    if let Ok(n) = s.parse::<usize>() {
                        if let Some(v) = self.palette.option_number(n) {
                            let v = v.to_string();
                            return Some(self.choose_accent_str(&v));
                        }
                    }
                    if s == " " {
                        if let Some(i) = self.palette.selected() {
                            let v = self.palette.options()[i].clone();
                            return Some(self.choose_accent_str(&v));
                        }
                    }
                }
                KeyInput::Left | KeyInput::Up => {
                    self.palette.move_by(-1);
                    return Some(Outcome {
                        marked: self.shown_text().to_string(),
                        handled: true,
                        ..Outcome::default()
                    });
                }
                KeyInput::Right | KeyInput::Down => {
                    self.palette.move_by(1);
                    return Some(Outcome {
                        marked: self.shown_text().to_string(),
                        handled: true,
                        ..Outcome::default()
                    });
                }
                KeyInput::Tab => {
                    self.palette.cycle();
                    return Some(Outcome {
                        marked: self.shown_text().to_string(),
                        handled: true,
                        ..Outcome::default()
                    });
                }
                KeyInput::Enter => {
                    if let Some(i) = self.palette.selected() {
                        let v = self.palette.options()[i].clone();
                        return Some(self.choose_accent_str(&v));
                    }
                }
                KeyInput::Escape => {
                    self.close_palette();
                    return Some(Outcome {
                        marked: self.shown_text().to_string(),
                        handled: true,
                        ..Outcome::default()
                    });
                }
                _ => {}
            }
            self.close_palette();
        }
        if let KeyInput::Text(s) = key {
            if is_repeat && AccentPalette::has_variants(s) && self.held_letter() == *s {
                self.palette.open(s);
                self.palette_letter = s.clone();
                return Some(Outcome {
                    marked: self.shown_text().to_string(),
                    handled: true,
                    ..Outcome::default()
                });
            }
            if self.suggester.is_some() {
                return None;
            }
            let before = std::mem::take(&mut self.pending);
            if AccentPalette::has_variants(s) {
                self.pending = s.clone();
                return Some(Outcome {
                    insert: before,
                    marked: s.clone(),
                    handled: true,
                    ..Outcome::default()
                });
            }
            if before.is_empty() {
                return None;
            }
            self.session.insert_text(s);
            return Some(Outcome {
                insert: before + &self.session.take_committed(),
                marked: String::new(),
                handled: true,
                ..Outcome::default()
            });
        }
        if self.suggester.is_some() || self.pending.is_empty() {
            return None;
        }
        let before = std::mem::take(&mut self.pending);
        match key {
            KeyInput::Backspace => Some(Outcome {
                marked: String::new(),
                handled: true,
                ..Outcome::default()
            }),
            KeyInput::Escape => Some(Outcome {
                insert: before,
                marked: String::new(),
                handled: true,
                ..Outcome::default()
            }),
            _ => Some(Outcome {
                insert: before,
                marked: String::new(),
                handled: false,
                ..Outcome::default()
            }),
        }
    }

    fn handle_suggesting(&mut self, key: &KeyInput) -> Option<Outcome> {
        if !self.is_latin() || self.suggester.is_none() {
            return None;
        }
        match key {
            KeyInput::Text(s) if SanskritSuggester::is_letter(s) => {
                self.suggester.as_mut().unwrap().type_letter(s);
                return Some(Outcome {
                    insert: s.clone(),
                    handled: true,
                    ..Outcome::default()
                });
            }
            KeyInput::Text(s) => {
                self.suggester.as_mut().unwrap().clear();
                self.session.insert_text(s);
                return Some(Outcome {
                    insert: self.session.take_committed(),
                    handled: true,
                    ..Outcome::default()
                });
            }
            KeyInput::Backspace => {
                if !self.suggester.as_mut().unwrap().backspace() {
                    return None;
                }
                return Some(Outcome {
                    handled: false,
                    ..Outcome::default()
                });
            }
            KeyInput::Escape => {
                if self.suggester.as_ref().unwrap().is_empty() {
                    return None;
                }
                self.suggester.as_mut().unwrap().clear();
                return Some(Outcome::handled_only());
            }
            KeyInput::Tab => {
                let s = self.suggester.as_mut().unwrap();
                if s.is_empty() {
                    return None;
                }
                let typed = s.buffer().to_string();
                if let Some(word) = s.accept() {
                    return Some(Outcome {
                        insert: word,
                        replacing: typed,
                        handled: true,
                        ..Outcome::default()
                    });
                }
                s.clear();
                return Some(Outcome {
                    handled: false,
                    ..Outcome::default()
                });
            }
            KeyInput::Up | KeyInput::Down => {
                let s = self.suggester.as_mut().unwrap();
                if s.shown().is_empty() {
                    // fall through to clear below
                } else {
                    s.move_by(if key.is_up() { -1 } else { 1 });
                    return Some(Outcome::handled_only());
                }
            }
            _ => {}
        }
        let s = self.suggester.as_mut().unwrap();
        if s.is_empty() {
            return None;
        }
        s.clear();
        Some(Outcome {
            handled: false,
            ..Outcome::default()
        })
    }

    /// `is_repeat` is true for the repeats of a held key (a long press).
    pub fn handle(&mut self, key: KeyInput, is_repeat: bool) -> Outcome {
        if let Some(out) = self.handle_accent(&key, is_repeat) {
            return out;
        }
        if let Some(out) = self.handle_suggesting(&key) {
            return out;
        }
        match &key {
            KeyInput::Text(s) => {
                self.session.insert_text(s);
                Outcome {
                    insert: self.session.take_committed(),
                    marked: self.session.provisional(),
                    handled: true,
                    ..Outcome::default()
                }
            }
            KeyInput::Backspace => {
                if !self.session.backspace() {
                    return Outcome::default();
                }
                Outcome {
                    marked: self.session.provisional(),
                    handled: true,
                    ..Outcome::default()
                }
            }
            KeyInput::Escape => {
                if self.session.raw().is_empty() {
                    return Outcome::default();
                }
                self.session.cancel();
                Outcome::handled_only()
            }
            KeyInput::Enter
            | KeyInput::Other
            | KeyInput::Tab
            | KeyInput::Up
            | KeyInput::Down
            | KeyInput::Left
            | KeyInput::Right => Outcome {
                insert: self.commit_all(),
                handled: false,
                ..Outcome::default()
            },
        }
    }

    pub fn is_latin(&self) -> bool {
        self.session.latin()
    }

    pub fn set_latin(&mut self, on: bool) -> Outcome {
        let word = self.flush_suggestion();
        self.session.set_latin(on);
        Outcome {
            insert: word + &self.session.take_committed(),
            marked: String::new(),
            handled: true,
            ..Outcome::default()
        }
    }

    pub fn commit_all(&mut self) -> String {
        self.flush_suggestion()
            + &{
                self.session.finish();
                self.session.take_committed()
            }
    }

    pub fn reset(&mut self) {
        if let Some(s) = &mut self.suggester {
            s.clear();
        }
        self.pending.clear();
        self.palette.close();
        self.session.cancel();
        let _ = self.session.take_committed();
    }

    fn flush_suggestion(&mut self) -> String {
        self.palette.close();
        let waiting = std::mem::take(&mut self.pending);
        if let Some(s) = &mut self.suggester {
            s.clear();
        }
        waiting
    }

    pub fn suggestion_json(&self) -> Option<String> {
        let (words, selected) = self.suggestion_list()?;
        use crate::json::string;
        let ws: Vec<String> = words.iter().map(|w| string(w)).collect();
        Some(format!(
            "{{\"words\":[{}],\"selected\":{},\"buffer\":{}}}",
            ws.join(","),
            selected,
            string(self.suggestion_buffer())
        ))
    }

    pub fn accent_json(&self) -> Option<String> {
        let (options, selected) = self.accent_list()?;
        use crate::json::string;
        let os: Vec<String> = options.iter().map(|o| string(o)).collect();
        let sel = match selected {
            Some(i) => i.to_string(),
            None => "null".to_string(),
        };
        Some(format!(
            "{{\"options\":[{}],\"selected\":{}}}",
            os.join(","),
            sel
        ))
    }
}
