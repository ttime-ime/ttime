//! Rough latency numbers; run with `cargo run --release -p ttime-core --example bench`.
//! Wall-clock only, one machine, no statistics: it exists to notice order-of-magnitude
//! problems, not to compare releases.

use std::time::Instant;
use ttime_core::{ewts_to_unicode, unicode_to_ewts, Engine};

fn time<F: FnMut()>(label: &str, iters: u32, mut f: F) {
    for _ in 0..iters / 10 {
        f();
    }
    let t = Instant::now();
    for _ in 0..iters {
        f();
    }
    let ns = t.elapsed().as_nanos() as f64 / iters as f64;
    println!("{label:<42} {ns:>12.0} ns");
}

fn main() {
    let word = "bsgrubs";
    let line = "bkra shis bde legs, sangs rgyas chos dang tshogs kyi mchog la skyabs su mchi/ ";
    let page = line.repeat(30);
    let tibetan = ewts_to_unicode(&page);

    time("ewts_to_unicode (1 syllable)", 200_000, || {
        std::hint::black_box(ewts_to_unicode(std::hint::black_box(word)));
    });
    time("ewts_to_unicode (1 line, ~75 chars)", 50_000, || {
        std::hint::black_box(ewts_to_unicode(std::hint::black_box(line)));
    });
    time("ewts_to_unicode (page, ~2,300 chars)", 2_000, || {
        std::hint::black_box(ewts_to_unicode(std::hint::black_box(&page)));
    });
    time("unicode_to_ewts (page)", 2_000, || {
        std::hint::black_box(unicode_to_ewts(std::hint::black_box(&tibetan)));
    });
    // One keystroke at the end of a growing buffer: the whole buffer is
    // re-converted each time.
    for n in [20usize, 200, 2000] {
        let mut e = Engine::new();
        for c in page.chars().take(n) {
            e.push(c);
        }
        time(
            &format!("keystroke preedit, buffer of {n} chars"),
            5_000,
            || {
                e.push('k');
                std::hint::black_box(e.preedit());
                e.backspace();
            },
        );
    }
}
