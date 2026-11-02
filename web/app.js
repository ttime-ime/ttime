import init, { Session, version } from "./pkg/ttime_wasm.js";

const $ = (id) => document.getElementById(id);
const editor = $("editor");

const EXAMPLES = [
  ["Ordinary text (other implementations agree)", [
    ["bod skad", "two syllables"],
    ["bkra shis bde legs", "prefix letters"],
    ["rgyal ba'i mdo", "stack, 'a-chung, genitive"],
    ["bsgrubs", "prefix, stack and two suffixes"],
    ["khong [New York] la phebs song /", "bracketed literal, shad (THL rule 9)"],
    ["gyon g.yon ", "stack versus prefix with a dot (THL rule 3)"],
    ["sat+t+wa", "explicit stack with + (THL rule 4)"],
    ["sarba mang+galaM ", "Sanskrit in one syllable (THL rule 7)"],
  ]],
  ["Open questions: please judge, do not trust", [
    ["oM maNi padme hUM", "oM becomes ༀ here; some converters give ཨོཾ"],
    ["kii", "repeated vowel: stacked here; others insert a-chen"],
    ["ghri", "gh + ra: separate here; others subjoin"],
    ["kaa", "second a is silently ignored here"],
  ]],
];

let session = null;
let typed = ""; // keystrokes since the last reset; null once direct edits make it unreliable
let prov = "";

function setStatus(msg) {
  $("status").textContent = msg;
  clearTimeout(setStatus.t);
  setStatus.t = setTimeout(() => ($("status").textContent = ""), 2500);
}

function render() {
  const committed = session.committed();
  prov = session.provisional();
  editor.value = committed + prov;
  if (prov) editor.setSelectionRange(committed.length, editor.value.length);
  else editor.setSelectionRange(editor.value.length, editor.value.length);
  inspect();
}

function atEnd() {
  const end = editor.value.length;
  if (editor.selectionEnd !== end) return false;
  if (editor.selectionStart === end) return true;
  return prov !== "" && editor.selectionStart === end - prov.length;
}

function commitProvisional() {
  if (session.raw() !== "") {
    session.finish();
    render();
  }
}

function inspect() {
  $("i-raw").textContent = session.raw();
  $("i-prov").textContent = prov;
  $("i-comm").textContent = session.committed();
  const cps = [...editor.value].slice(0, 300).map((c) => c.codePointAt(0).toString(16).toUpperCase().padStart(4, "0"));
  $("i-cp").textContent = cps.join(" ") + ([...editor.value].length > 300 ? " …" : "");
  const nfc = editor.value.normalize("NFC") === editor.value;
  $("i-nf").textContent = editor.value === "" ? "—" : nfc ? "NFC (unchanged by normalization)" : "Not NFC: normalizing would change this text";
  const ul = $("i-diag");
  ul.textContent = "";
  const diags = JSON.parse(session.diagnostics_json());
  if (diags.length === 0) {
    const li = document.createElement("li");
    li.textContent = "none";
    ul.append(li);
  }
  for (const d of diags) {
    const li = document.createElement("li");
    li.textContent = `${d.code} (${d.severity}, bytes ${d.start}–${d.end}): ${d.message}`;
    ul.append(li);
  }
  report();
}

function report() {
  const include = $("include-text").checked;
  const lines = [
    `T-Time Writing Room report`,
    `Version: ${version()}`,
    `Browser: ${navigator.userAgent}`,
    `Precomposed output: ${session.precomposed()}`,
  ];
  if (include) {
    lines.push(`EWTS typed: ${typed === null ? "(not available: text was edited directly)" : JSON.stringify(typed)}`);
    lines.push(`Editor text: ${JSON.stringify(editor.value)}`);
    lines.push(`Code points: ${$("i-cp").textContent}`);
  } else {
    lines.push("(editor text omitted by the sender)");
  }
  lines.push(`Expected: ${$("expected").value || "(not given)"}`);
  lines.push(`Comment: ${$("comment").value || "(none)"}`);
  $("report").textContent = lines.join("\n");
}

function newSession(precomposed, keepFrom) {
  const s = new Session(precomposed);
  if (keepFrom) {
    s.set_committed(keepFrom.committed());
    s.insert_text(keepFrom.raw());
    keepFrom.free();
  }
  return s;
}

function bind() {
  editor.addEventListener("beforeinput", (e) => {
    if (!$("ewts-on").checked || e.isComposing) return;
    const t = e.inputType;
    if (!atEnd()) {
      if (prov !== "") commitProvisional();
      return; // ordinary editing; resynced on "input"
    }
    if (t === "insertText" && e.data) {
      e.preventDefault();
      session.insert_text(e.data);
      if (typed !== null) typed += e.data;
      render();
    } else if (t === "insertLineBreak" || (t === "insertParagraph")) {
      e.preventDefault();
      session.insert_text("\n");
      if (typed !== null) typed += "\n";
      render();
    } else if (t === "deleteContentBackward") {
      if (session.backspace()) {
        e.preventDefault();
        if (typed !== null) typed = typed.slice(0, -1);
        render();
      } else if (prov === "") {
        typed = null; // browser deletes committed text
      }
    } else if (prov !== "") {
      commitProvisional(); // paste, cut, drop, ...
      typed = null;
    }
  });

  editor.addEventListener("input", () => {
    // Only reached for edits the browser performed itself.
    session.set_committed(editor.value);
    typed = null;
    prov = "";
    inspect();
  });
  editor.addEventListener("pointerdown", () => commitProvisional());
  editor.addEventListener("blur", () => commitProvisional());

  $("copy").addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(editor.value);
      setStatus("Copied");
    } catch {
      editor.select();
      setStatus("Press Ctrl/Cmd+C");
    }
  });
  $("clear").addEventListener("click", () => {
    session.reset();
    typed = "";
    render();
    editor.focus();
  });
  $("precomposed").addEventListener("change", (e) => {
    session = newSession(e.target.checked, session);
    render();
  });
  $("ewts-on").addEventListener("change", (e) => {
    if (!e.target.checked) commitProvisional();
    setStatus(e.target.checked ? "EWTS typing on" : "EWTS typing off");
  });
  $("font").addEventListener("change", (e) => {
    const v = e.target.value;
    const f = { auto: "", noto: '"Noto Serif Tibetan"', jomolhari: '"Jomolhari"', kailasa: '"Kailasa"' }[v];
    editor.style.fontFamily = f ? `${f}, serif` : "";
  });
  for (const id of ["expected", "comment", "include-text"]) $(id).addEventListener("input", report);
  $("copy-report").addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText($("report").textContent);
      setStatus("Report copied");
    } catch {
      setStatus("Select the report text and copy it");
    }
  });
}

function buildExamples() {
  const host = $("examples");
  for (const [title, items] of EXAMPLES) {
    const h = document.createElement("h3");
    h.textContent = title;
    const row = document.createElement("div");
    row.className = "row";
    for (const [ewts, note] of items) {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = ewts.trim();
      const small = document.createElement("small");
      small.textContent = note;
      b.append(small);
      b.addEventListener("click", () => {
        session.reset();
        typed = "";
        session.insert_text(ewts);
        typed = ewts;
        render();
        editor.focus();
      });
      row.append(b);
    }
    host.append(h, row);
  }
}

await init();
$("build").textContent = version();
session = new Session(false);
buildExamples();
bind();
render();
editor.focus();
window.__ttime = { get session() { return session; } };
