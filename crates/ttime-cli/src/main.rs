use std::io::{self, BufRead};

use ttime_core::{ewts_to_unicode_with, Options};

fn main() {
    let precomposed = std::env::args().skip(1).any(|a| a == "--precomposed");
    let options = Options { precomposed };
    for line in io::stdin().lock().lines() {
        let line = line.expect("failed to read stdin");
        println!("{}", ewts_to_unicode_with(&line, options));
    }
}
