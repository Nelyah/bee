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
            ("/custom/xdg/bee/bee-data.json".to_string()),
            ("/home/user/.local/share/bee/bee-data.json".to_string()),
            ("/custom/xdg/bee/bee-logged-tasks.json".to_string()),
            ("/home/user/.local/share/bee/bee-logged-tasks.json".to_string()),
            ("bee-data.json".to_string()),
            ("bee-logged-tasks.json".to_string()),
        ]),
    };

    let mut mock_env = MockEnv {
        vars: HashMap::from([
            ("XDG_DATA_HOME".to_string(), "/custom/xdg".to_string()),
            ("HOME".to_string(), "/home/user".to_string()),
        ]),
    };

    // First test
    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/custom/xdg/bee/bee-data.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-logged-tasks.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/custom/xdg/bee/bee-logged-tasks.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    // Changing XDG_DATA_HOME to a bad value
    mock_env
        .vars
        .insert("XDG_DATA_HOME".to_string(), "/bad/value".to_string());
    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/home/user/.local/share/bee/bee-data.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-logged-tasks.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "/home/user/.local/share/bee/bee-logged-tasks.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    mock_env
        .vars
        .insert("HOME".to_string(), "/bad/value".to_string());
    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "bee-data.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-logged-tasks.json", true);
    match path {
        Ok(p) => {
            assert_eq!(p, "bee-logged-tasks.json");
        }
        Err(_) => {
            unreachable!();
        }
    }

    let mock_fs = MockFileSystem {
        files: HashSet::from([
            "/custom/xdg/bee/bee-data.json".to_string(),
            "/home/user/.local/share/bee/bee-data.json".to_string(),
            "/custom/xdg/bee/bee-logged-tasks.json".to_string(),
            "/home/user/.local/share/bee/bee-logged-tasks.json".to_string(),
        ]),
    };

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true);
    assert!(path.is_err());

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-logged-tasks.json", true);
    assert!(path.is_err());

    let mock_fs = MockFileSystem {
        files: HashSet::from([
            "/custom/xdg/bee/bee-data.json".to_string(),
            "/home/user/.local/share/bee/bee-data.json".to_string(),
            "/custom/xdg/bee/bee-logged-tasks.json".to_string(),
            "/home/user/.local/share/bee/bee-logged-tasks.json".to_string(),
        ]),
    };

    let mock_env = MockEnv {
        vars: HashMap::from([]),
    };

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true);
    if let Ok(p) = path {
        assert_eq!(p, "bee-data.json");
    }

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-logged-tasks.json", true);
    if let Ok(p) = path {
        assert_eq!(p, "bee-logged-tasks.json");
    }
}

#[test]
fn test_find_data_file_with_custom_data_home() {
    let mock_fs = MockFileSystem {
        files: HashSet::from([
            ("/custom/bee/bee-data.json".to_string()),
            ("/custom/bee/bee-logged-tasks.json".to_string()),
            ("/custom/xdg/bee/bee-data.json".to_string()),
            ("/custom/xdg/bee/bee-logged-tasks.json".to_string()),
        ]),
    };

    let mut mock_env = MockEnv {
        vars: HashMap::from([
            ("XDG_DATA_HOME".to_string(), "/custom/xdg".to_string()),
            ("HOME".to_string(), "/home/user".to_string()),
        ]),
    };

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true).unwrap();
    assert_eq!(path, "/custom/xdg/bee/bee-data.json");

    mock_env
        .vars
        .insert("BEE_DATA_HOME".to_string(), "/custom/bee".to_string());

    let path = get_data_file_impl(&mock_fs, &mock_env, "bee-data.json", true);
    assert_eq!(path.unwrap(), "/custom/bee/bee-data.json");
}
