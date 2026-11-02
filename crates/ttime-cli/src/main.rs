use std::io::{self, BufRead};

use ttime_core::ewts_to_unicode;

fn main() {
    for line in io::stdin().lock().lines() {
        let line = line.expect("failed to read stdin");
        println!("{}", ewts_to_unicode(&line));
    }
}
