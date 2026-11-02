use std::fs;
fn esc(s: &str) -> String {
    s.chars()
        .map(|c| format!("{:04X}", c as u32))
        .collect::<Vec<_>>()
        .join(" ")
}
fn main() {
    let conv = ewts::EwtsConverter::create();
    let dir = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../crates/ttime-core/tests/fixtures"
    );
    let mut files: Vec<_> = fs::read_dir(dir)
        .unwrap()
        .map(|e| e.unwrap().path())
        .collect();
    files.sort();
    let (mut n, mut d) = (0, 0);
    for f in files {
        let name = f.file_name().unwrap().to_str().unwrap().to_string();
        if name == "precomposed.tsv" || !name.ends_with(".tsv") {
            continue;
        }
        for l in fs::read_to_string(&f).unwrap().lines() {
            if l.is_empty() || l.starts_with('#') {
                continue;
            }
            let inp = l.split('\t').next().unwrap();
            let theirs =
                std::panic::catch_unwind(|| conv.ewts_to_unicode(inp)).unwrap_or("<panic>".into());
            let ours = ttime_core::ewts_to_unicode(inp);
            n += 1;
            if theirs != ours {
                d += 1;
                println!(
                    "{name}\t{inp:?}\n   ours {}\n   ewts {}",
                    esc(&ours),
                    esc(&theirs)
                );
            }
        }
    }
    println!("{n} cases, {d} differ");
}
