#[cfg(test)]
use super::*;
use super::{Env, FileSystem};

use std::fs;
use std::io;

use std::collections::{HashMap, HashSet};

// Mocking file system and environment
#[allow(dead_code)]
struct MockFileSystem {
    files: HashSet<String>, // A set of file paths that exist
}

#[allow(dead_code)]
struct MockEnv {
    vars: HashMap<String, String>,
}

impl FileSystem for MockFileSystem {
    fn stat(&self, name: &str) -> io::Result<fs::Metadata> {
        if self.files.contains(name) {
            return fs::metadata("/");
        }
        fs::metadata("/thisdoesnotexists")
    }
}

impl Env for MockEnv {
    fn getenv(&self, key: &str) -> Option<String> {
        self.vars.get(key).cloned()
    }
}

#[test]
fn test_find_data_file() {
    let mock_fs = MockFileSystem {
        files: HashSet::from([
            ("/custom/xdg/rusk/rusk-data.json".to_string()),
            ("/home/user/.local/share/rusk/rusk-data.json".to_string()),
            ("/custom/xdg/rusk/rusk-logged-tasks.json".to_string()),
            ("/home/user/.local/share/rusk/rusk-logged-tasks.json".to_string()),
            ("rusk-data.json".to_string()),
            ("rusk-logged-tasks.json".to_string()),
        ]),
    };

    let mut mock_env = MockEnv {
        vars: HashMap::from([
            ("XDG_DATA_HOME".to_string(), "/custom/xdg".to_string()),
            ("HOME".to_string(), "/home/user".to_string()),
        ]),
    };

    // First test
    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-data.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/custom/xdg/rusk/rusk-data.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-logged-tasks.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/custom/xdg/rusk/rusk-logged-tasks.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    // Changing XDG_DATA_HOME to a bad value
    mock_env
        .vars
        .insert("XDG_DATA_HOME".to_string(), "/bad/value".to_string());
    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-data.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/home/user/.local/share/rusk/rusk-data.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-logged-tasks.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/home/user/.local/share/rusk/rusk-logged-tasks.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    mock_env
        .vars
        .insert("HOME".to_string(), "/bad/value".to_string());
    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-data.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "rusk-data.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-logged-tasks.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "rusk-logged-tasks.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let mock_fs = MockFileSystem {
        files: HashSet::from([
            "/custom/xdg/rusk/rusk-data.json".to_string(),
            "/home/user/.local/share/rusk/rusk-data.json".to_string(),
            "/custom/xdg/rusk/rusk-logged-tasks.json".to_string(),
            "/home/user/.local/share/rusk/rusk-logged-tasks.json".to_string(),
        ]),
    };

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-data.json", true);
    assert!(path.is_err());

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-logged-tasks.json", true);
    assert!(path.is_err());

    let mock_fs = MockFileSystem {
        files: HashSet::from([
            "/custom/xdg/rusk/rusk-data.json".to_string(),
            "/home/user/.local/share/rusk/rusk-data.json".to_string(),
            "/custom/xdg/rusk/rusk-logged-tasks.json".to_string(),
            "/home/user/.local/share/rusk/rusk-logged-tasks.json".to_string(),
        ]),
    };

    let mock_env = MockEnv {
        vars: HashMap::from([]),
    };

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-data.json", true);
    if let Ok(p) = path {
        assert_eq!(p, "rusk-data.json");
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "rusk-logged-tasks.json", true);
    if let Ok(p) = path {
        assert_eq!(p, "rusk-logged-tasks.json");
    }
}
