use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

struct TestWorkspace {
    root: PathBuf,
    data_home: PathBuf,
}

/// Creates an isolated workspace with a minimal config and data directories.
fn setup_workspace() -> TestWorkspace {
    let root = unique_temp_dir();
    let data_home = root.join("data");
    fs::create_dir_all(&data_home).expect("failed to create data dir");
    write_minimal_config(&root);

    TestWorkspace { root, data_home }
}

/// Creates a unique temporary directory path for this test process.
fn unique_temp_dir() -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time went backwards")
        .as_nanos();
    let dir_name = format!("bee-cli-it-{}-{}", std::process::id(), nanos);
    let root = std::env::temp_dir().join(dir_name);
    fs::create_dir_all(&root).expect("failed to create temp dir");
    root
}

/// Writes a minimal bee.toml config file to the given root.
fn write_minimal_config(root: &Path) {
    let contents = "[core]\n\n[cli]\n";
    fs::write(root.join("bee.toml"), contents).expect("failed to write bee.toml");
}

/// Runs the bee CLI in the given workspace and returns stdout as a String.
fn run_bee(workspace: &TestWorkspace, args: &[&str]) -> String {
    let output = Command::new(env!("CARGO_BIN_EXE_bee"))
        .args(args)
        .current_dir(&workspace.root)
        .env("BEE_DATA_HOME", &workspace.data_home)
        .env("HOME", &workspace.root)
        .env("XDG_CONFIG_HOME", &workspace.root)
        .output()
        .expect("failed to run bee");

    assert!(
        output.status.success(),
        "bee failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    String::from_utf8_lossy(&output.stdout).to_string()
}

#[test]
fn add_then_filter_by_id_shows_single_task() {
    let workspace = setup_workspace();

    run_bee(&workspace, &["add", "foo"]);
    run_bee(&workspace, &["add", "bar"]);

    let stdout = run_bee(&workspace, &["1"]);

    assert!(
        stdout.contains("foo"),
        "expected foo in output, got: {}",
        stdout
    );
    assert!(
        !stdout.contains("bar"),
        "expected bar to be filtered out, got: {}",
        stdout
    );
}
