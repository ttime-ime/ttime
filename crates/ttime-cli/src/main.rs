//! Line-oriented test harness for the conversion engine.
//!
//!     ttime-cli                  EWTS -> Unicode
//!     ttime-cli --precomposed    ... emitting precomposed characters
//!     ttime-cli --diagnostics    ... and print diagnostics to stderr
//!     ttime-cli --reverse        Unicode -> EWTS (fidelity and diagnostics to stderr)

use std::io::{self, BufRead};

use ttime_core::{convert, unicode_to_ewts, Options};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let flag = |name: &str| args.iter().any(|a| a == name);
    let options = Options {
        precomposed: flag("--precomposed"),
    };

    for line in io::stdin().lock().lines() {
        let line = line.expect("failed to read stdin");
        if flag("--reverse") {
            let r = unicode_to_ewts(&line);
            println!("{}", r.text);
            if flag("--diagnostics") {
                eprintln!("{:?}", r.fidelity);
                for d in &r.diagnostics {
                    eprintln!(
                        "  {} {:?} {}..{}: {}",
                        d.code.as_str(),
                        d.severity,
                        d.span.start,
                        d.span.end,
                        d.message
                    );
                }
            }
        } else {
            let c = convert(&line, options);
            println!("{}", c.text);
            if flag("--diagnostics") {
                for d in &c.diagnostics {
                    eprintln!(
                        "  {} {:?} {}..{}: {}",
                        d.code.as_str(),
                        d.severity,
                        d.span.start,
                        d.span.end,
                        d.message
                    );
                }
            }
        }
    }
}
