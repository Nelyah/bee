use log::debug;
use uuid::Uuid;

use bee_actions::ActionUndo;
use bee_core::{
    filters::{self, Filter},
    task::{DependsOnIdentifier, TaskData, TaskProperties},
};

use std::collections::HashMap;
use std::env;
use std::fs;
use std::io;
use std::io::Read;
use std::path::{Path, PathBuf};

#[path = "storage_test.rs"]
mod storage_test;

pub trait Store {
    #[allow(clippy::borrowed_box)]
    fn load_tasks(
        filter: Option<&Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> Result<TaskData, String>;
    /// Will write the task and return the TaskData written
    fn write_tasks(data: &TaskData) -> Result<TaskData, String>;
    fn load_undos(last_count: usize) -> Vec<ActionUndo>;
    fn log_undo(count: usize, updated_undos: Vec<ActionUndo>);
}

#[derive(Default)]
pub struct JsonStore {}

impl Store for JsonStore {
    #[allow(clippy::borrowed_box)]
    fn load_tasks(
        filter: Option<&Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> Result<TaskData, String> {
        debug!(
            "Loading tasks using filter:\n{}",
            &filter.unwrap_or(&filters::new_empty()).to_string()
        );
        let mut data = match find_data_file() {
            Ok(data_file) => {
                serde_json::from_str(&fs::read_to_string(data_file).expect("unable to read file"))
                    .unwrap()
            }
            Err(_) => TaskData::default(),
        };

        data.upkeep()?;

        // We need to keep some knowledge of how the ids map to the uuids
        let mut id_to_uuid = HashMap::<usize, Uuid>::default();
        for task in data
            .get_task_map()
            .values()
            .filter(|t| t.get_id().is_some())
        {
            id_to_uuid.insert(task.get_id().unwrap(), *task.get_uuid());
        }
        for (id, uuid) in id_to_uuid.iter() {
            data.insert_id_to_uuid(*id, *uuid);
        }

        // Load extra UUIDs from loaded tasks
        let mut new_data = if let Some(filter) = filter {
            let mut filter_mut = filter.clone();
            filter_mut.convert_id_to_uuid(&id_to_uuid);
            data.filter(&filter_mut)
        } else {
            data.to_owned()
        };
        debug!(
            "Loaded {} tasks (out of {} total tasks).",
            new_data.get_task_map().len(),
            data.get_task_map().len()
        );

        // TODO: I need to get all the tasks that can be possibly reached from the
        // filtered tasks. Currently I am only reaching the classes that are first
        // degree neighbour of my filtered tasks.
        // Allowing all tasks will allow to update their field accordingly when we're
        // going dependency update and such.
        let extra_uuids: Vec<_> = new_data
            .get_task_map()
            .values()
            .flat_map(|task| task.get_extra_uuid())
            .collect();

        // Load extra uuids from the TaskProperties
        if let Some(props) = props {
            for task_identifier in props.get_referenced_tasks() {
                match task_identifier {
                    DependsOnIdentifier::Uuid(uuid) => {
                        debug!("Adding extra task with uuid {} from TaskProperties", uuid);
                        new_data.insert_extra_task(data.get_owned(&uuid).unwrap())
                    }
                    DependsOnIdentifier::Usize(id) => {
                        if let Some(uuid) = id_to_uuid.get(&id) {
                            debug!(
                                "Adding extra task with id {} and uuid {} from TaskProperties",
                                id, uuid
                            );
                            new_data.insert_extra_task(data.get_owned(uuid).unwrap())
                        } else {
                            unreachable!("Could not find task with id {}", id);
                        }
                    }
                }
            }
        }

        for uuid in extra_uuids {
            let task = data.get_owned(&uuid).unwrap();
            debug!(
                "Adding extra task with id {:?} and uuid {} as extra task",
                task.get_id(),
                uuid
            );
            new_data.insert_extra_task(data.get_owned(&uuid).unwrap())
        }

        Ok(new_data)
    }

    fn write_tasks(data: &TaskData) -> Result<TaskData, String> {
        let mut stored_tasks = Self::load_tasks(None, None)?;
        for t in data.get_task_map().values() {
            stored_tasks.set_task(t.clone());
        }
        stored_tasks.upkeep()?;

        let tasks_as_json =
            serde_json::to_string_pretty(&stored_tasks).expect("Failed to serialize tasks to JSON");

        match find_data_file() {
            Ok(_) => (),
            Err(_) => create_path_if_not_exist(&get_data_file_path()),
        }

        let data_file = find_data_file().expect("Failed to find data file");

        fs::write(data_file, tasks_as_json).expect("Could not write data file");

        Ok(stored_tasks)
    }

    fn load_undos(last_count: usize) -> Vec<ActionUndo> {
        match find_logged_file() {
            Ok(data_file) => {
                let undos: Vec<ActionUndo> = serde_json::from_str(
                    &fs::read_to_string(data_file).expect("unable to read file"),
                )
                .unwrap();
                let len = undos.len();
                if last_count >= len {
                    undos[..].to_vec()
                } else {
                    undos[len - last_count..].to_vec()
                }
            }
            Err(_) => Vec::default(),
        }
    }

    fn log_undo(count: usize, updated_undos: Vec<ActionUndo>) {
        // Assuming find_logged_file and create_path_if_not_exist functions exist
        let data_file = match find_logged_file() {
            Ok(file) => file,
            Err(_) => {
                create_path_if_not_exist(&get_logged_tasks_file_path());
                find_logged_file().expect("Failed to find or create logged file")
            }
        };

        let mut undos: Vec<ActionUndo> = Vec::new();

        if let Ok(mut file) = fs::File::open(&data_file) {
            let mut data = String::new();
            file.read_to_string(&mut data)
                .expect("Failed to read data file");
            if !data.is_empty() {
                undos = serde_json::from_str(&data).expect("Failed to parse JSON");
            }
        }

        if undos.len() <= count {
            undos = updated_undos;
        } else {
            undos.splice(undos.len() - count.., updated_undos);
        }

        let updated_data = serde_json::to_string_pretty(&undos).expect("Failed to serialize data");
        fs::write(&data_file, updated_data).expect("Failed to write to data file");
    }
}

// Function to create a path if it doesn't exist
fn create_path_if_not_exist(path: &str) {
    fs::create_dir_all(
        Path::new(path)
            .parent()
            .expect("Failed to get directory part of path"),
    )
    .expect("Failed to create directories");

    fs::File::create(path).expect("Failed to create or truncate the file");
    // File is automatically closed when it goes out of scope
}

// FileSystem trait for abstracting file system operations
trait FileSystem {
    fn stat(&self, name: &str) -> io::Result<fs::Metadata>;
}

// Env trait for abstracting environment variable access
trait Env {
    fn getenv(&self, key: &str) -> Option<String>;
}

// Default implementations
struct RealFileSystem;
struct RealEnv;

impl FileSystem for RealFileSystem {
    fn stat(&self, name: &str) -> io::Result<fs::Metadata> {
        fs::metadata(name)
    }
}

impl Env for RealEnv {
    fn getenv(&self, key: &str) -> Option<String> {
        env::var(key).ok()
    }
}

// Function to find data file
fn find_data_file() -> Result<String, io::Error> {
    get_data_file_impl(&RealFileSystem, &RealEnv, "bee-data.json", true)
}

fn get_data_file_path() -> String {
    get_data_file_impl(&RealFileSystem, &RealEnv, "bee-data.json", false).unwrap_or_default()
}

fn get_logged_tasks_file_path() -> String {
    get_data_file_impl(&RealFileSystem, &RealEnv, "bee-logged-tasks.json", false)
        .unwrap_or_default()
}

fn find_logged_file() -> Result<String, io::Error> {
    get_data_file_impl(&RealFileSystem, &RealEnv, "bee-logged-tasks.json", true)
}

// getDataFileImpl provides utility to find where we store the file on the filesystem
fn get_data_file_impl<'a>(
    fs: &(impl FileSystem + 'a),
    env: &(impl Env + 'a),
    filename: &str,
    find_file_only: bool,
) -> Result<String, io::Error> {
    if filename != "bee-data.json" && filename != "bee-logged-tasks.json" {
        panic!("Invalid filename given to 'get_data_file_impl'");
    }

    if let Some(bee_data_home) = env.getenv("BEE_DATA_HOME") {
        debug!("Read 'BEE_DATA_HOME' env variable as '{}'", bee_data_home);
        let dir_path = PathBuf::from(&bee_data_home);
        let file_path = dir_path.join(filename).to_string_lossy().into_owned();

        if !find_file_only {
            debug!(
                "Bee data file should be located at {}",
                env.getenv("BEE_DATA_HOME").unwrap()
            );
            return Ok(file_path);
        }
        if fs.stat(&file_path).is_ok() {
            debug!(
                "Bee data file exists at {}",
                env.getenv("BEE_DATA_HOME").unwrap()
            );
            return Ok(file_path);
        }
        return Err(io::Error::new(io::ErrorKind::NotFound, "File not found"));
    }

    // Check $XDG_DATA_HOME/bee/data.json
    if let Some(xdg_data_home) = env.getenv("XDG_DATA_HOME") {
        let xdg_path = PathBuf::from(xdg_data_home).join("bee").join(filename);
        if !find_file_only {
            return Ok(xdg_path.to_string_lossy().into_owned());
        }
        if fs.stat(&xdg_path.to_string_lossy()).is_ok() {
            return Ok(xdg_path.to_string_lossy().into_owned());
        }
    }

    // Check $HOME/.local/share/bee/bee-data.json
    if let Some(home) = env.getenv("HOME") {
        let home_path = PathBuf::from(home)
            .join(".local")
            .join("share")
            .join("bee")
            .join(filename);
        if !find_file_only {
            return Ok(home_path.to_string_lossy().into_owned());
        }
        if fs.stat(&home_path.to_string_lossy()).is_ok() {
            return Ok(home_path.to_string_lossy().into_owned());
        }
    }

    // Check config.toml in the current directory
    let local_path = PathBuf::from(filename);
    if fs.stat(&local_path.to_string_lossy()).is_ok() {
        return Ok(local_path.to_string_lossy().into_owned());
    }

    if find_file_only {
        return Err(io::Error::new(io::ErrorKind::NotFound, "File not found"));
    }
    Ok(filename.to_owned())
}
