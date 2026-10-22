//! Build the workspace tests once, then run a bounded number of binaries concurrently.
//! Geometry includes a strict timing assertion, so run that binary without competing jobs.
//! Run doc/wasm side jobs afterward, without oversubscribing CPU or memory.

use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::mpsc;
use std::time::Instant;

use crate::{cargo, root};

/// A test executable from `cargo test --no-run`.
struct TestBin {
    label: String,
    exe: String,
    dir: String,
}

/// Build the tests with `cargo_args` (e.g. `--locked`), run each binary with `test_args`, and run
/// the `side` jobs one after another afterward. Each prints a line when it ends; a failure prints
/// its whole output.
pub fn run(cargo_args: &[&str], test_args: &[&str], side: Vec<(String, Command)>) -> Result<(), String> {
    let mut bins = build(cargo_args)?;
    let count = bins.len();
    let start = Instant::now();
    let mut failed = Vec::new();
    let execute = |b: &TestBin| {
        let mut c = Command::new(&b.exe);
        c.args(test_args).current_dir(&b.dir).env("CARGO_MANIFEST_DIR", &b.dir).env("RUST_TEST_THREADS", "2");
        finish(c)
    };
    // Keep the existing 200 ms performance assertion, without other test binaries
    // or background compilation competing for its CPU time.
    if let Some(index) = bins.iter().position(|b| b.label == "geom lib solidcraft_geom") {
        let b = bins.remove(index);
        let t0 = Instant::now();
        report(&b.label, execute(&b), t0.elapsed().as_secs_f64(), &mut failed);
    }
    let workers = std::thread::available_parallelism().map(usize::from).unwrap_or(1).min(2);
    println!("test: {count} binaries, at most {workers} concurrent; geometry runs first, side jobs last");
    let next = AtomicUsize::new(0);
    let (tx, rx) = mpsc::channel::<(String, Result<String, String>, f64)>();
    std::thread::scope(|scope| {
        for _ in 0..workers {
            let tx = tx.clone();
            let bins = &bins;
            let next = &next;
            let execute = &execute;
            scope.spawn(move || {
                while let Some(b) = bins.get(next.fetch_add(1, Ordering::Relaxed)) {
                    let t0 = Instant::now();
                    let _ = tx.send((b.label.clone(), execute(b), t0.elapsed().as_secs_f64()));
                }
            });
        }
        drop(tx);
        for (label, result, secs) in rx {
            report(&label, result, secs, &mut failed);
        }
    });
    for (label, command) in side {
        let t0 = Instant::now();
        report(&label, finish(command), t0.elapsed().as_secs_f64(), &mut failed);
    }
    println!("test: {count} binaries in {:.1}s", start.elapsed().as_secs_f64());
    if failed.is_empty() { Ok(()) } else { Err(format!("failed: {}", failed.join(", "))) }
}

fn report(label: &str, result: Result<String, String>, secs: f64, failed: &mut Vec<String>) {
    match result {
        Ok(summary) => println!("ok    {label:<44} {secs:6.1}s  {summary}"),
        Err(output) => {
            println!("FAIL  {label:<44} {secs:6.1}s\n{output}");
            failed.push(label.to_string());
        }
    }
}

/// Run to the end: the last `test result:` line on success, all output on failure.
fn finish(mut c: Command) -> Result<String, String> {
    let out = c.stdin(Stdio::null()).output().map_err(|e| format!("failed to spawn: {e}"))?;
    let stdout = String::from_utf8_lossy(&out.stdout);
    if out.status.success() {
        Ok(stdout.lines().rev().find(|l| l.starts_with("test result:")).unwrap_or("").trim_start_matches("test result: ").to_string())
    } else {
        Err(format!("{stdout}{}\n({})", String::from_utf8_lossy(&out.stderr), out.status))
    }
}

/// `cargo test --workspace --profile ci --no-run`, and the executables it built.
fn build(cargo_args: &[&str]) -> Result<Vec<TestBin>, String> {
    let mut c = cargo();
    c.args(["test", "--workspace", "--profile", "ci", "--no-run", "--message-format=json-render-diagnostics"]).args(cargo_args);
    eprintln!("$ cargo test --workspace --profile ci --no-run");
    let out = c.stderr(Stdio::inherit()).output().map_err(|e| format!("cargo test --no-run: failed to spawn: {e}"))?;
    if !out.status.success() {
        return Err(format!("cargo test --no-run: exited with {}", out.status));
    }
    let mut bins: Vec<TestBin> = Vec::new();
    for line in String::from_utf8_lossy(&out.stdout).lines() {
        let Ok(m) = serde_json::from_str::<serde_json::Value>(line) else { continue };
        let Some(exe) = m["executable"].as_str().filter(|_| m["reason"] == "compiler-artifact" && m["profile"]["test"] == true) else {
            continue;
        };
        if bins.iter().any(|b| b.exe == exe) {
            continue;
        }
        let manifest = std::path::Path::new(m["manifest_path"].as_str().unwrap_or_default()).to_path_buf();
        let dir = manifest.parent().map(|d| d.to_path_buf()).unwrap_or_else(root);
        let pkg = dir.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        let kind = m["target"]["kind"][0].as_str().unwrap_or("");
        let label = format!("{pkg} {kind} {}", m["target"]["name"].as_str().unwrap_or(""));
        bins.push(TestBin { label, exe: exe.to_string(), dir: dir.to_string_lossy().into_owned() });
    }
    if bins.is_empty() {
        return Err("cargo test --no-run built no test executables".into());
    }
    Ok(bins)
}

/// The doc tests (`cargo test --doc`), to run as a side job.
pub fn doc_tests(cargo_args: &[&str], test_args: &[&str]) -> (String, Command) {
    let mut c = cargo();
    c.args(["test", "--workspace", "--profile", "ci", "--doc"]).args(cargo_args).arg("--").args(test_args);
    ("doc tests".into(), c)
}
