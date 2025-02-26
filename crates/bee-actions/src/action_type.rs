use std::collections::HashMap;

use strum::{Display, EnumIter, IntoEnumIterator};

use crate::{
    BaseTaskAction, TaskAction, action_add::AddTaskAction, action_annotate::AnnotateTaskAction,
    action_cmd::CmdTaskAction, action_delete::DeleteTaskAction, action_done::DoneTaskAction,
    action_edit::EditTaskAction, action_export::ExportTaskAction, action_help::HelpTaskAction,
    action_info::InfoTaskAction, action_list::ListTaskAction, action_modify::ModifyTaskAction,
    action_start::StartTaskAction, action_stop::StopTaskAction, action_undo::UndoTaskAction,
};

pub struct ActionTypeData {
    pub parsed_string: Vec<String>,
    pub use_arguments_as_filter: bool,
    pub documentation_string: String,
}

#[derive(Debug, PartialEq, Eq, Hash, Display, EnumIter)]
pub enum ActionType {
    Add,
    Annotate,
    Command,
    Delete,
    Done,
    Edit,
    Export,
    Help,
    Info,
    List,
    Modify,
    Start,
    Stop,
    Undo,
}

impl ActionType {
    pub fn as_dict() -> HashMap<ActionType, ActionTypeData> {
        // Make sure all cases are handled, if we had a new variant then this function should
        // fail to compile, hopefully we don't forget to add to the dictionary as well
        let a = ActionType::List;
        match a {
            ActionType::Add => (),
            ActionType::Annotate => (),
            ActionType::Command => (),
            ActionType::Delete => (),
            ActionType::Done => (),
            ActionType::Edit => (),
            ActionType::Export => (),
            ActionType::Help => (),
            ActionType::Info => (),
            ActionType::List => (),
            ActionType::Modify => (),
            ActionType::Start => (),
            ActionType::Stop => (),
            ActionType::Undo => (),
        }
        let mut map = HashMap::new();

        for action_type in ActionType::iter() {
            match action_type {
                ActionType::Add => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["add".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: AddTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Annotate => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["annotate".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: { AnnotateTaskAction::get_command_description() },
                        },
                    );
                }
                ActionType::Command => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["_cmd".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: CmdTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Delete => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["delete".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: DeleteTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Done => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["done".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: DoneTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Edit => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["edit".to_string()],
                            use_arguments_as_filter: true,
                            documentation_string: EditTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Export => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["export".to_string()],
                            use_arguments_as_filter: true,
                            documentation_string: ExportTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Help => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["help".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: HelpTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Info => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["info".to_string()],
                            use_arguments_as_filter: true,
                            documentation_string: InfoTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::List => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["list".to_string()],
                            use_arguments_as_filter: true,
                            documentation_string: ListTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Modify => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["modify".to_string(), "mod".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: ModifyTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Start => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["start".to_string()],
                            use_arguments_as_filter: true,
                            documentation_string: StartTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Stop => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["stop".to_string()],
                            use_arguments_as_filter: true,
                            documentation_string: StopTaskAction::get_command_description(),
                        },
                    );
                }
                ActionType::Undo => {
                    map.insert(
                        action_type,
                        ActionTypeData {
                            parsed_string: vec!["undo".to_string()],
                            use_arguments_as_filter: false,
                            documentation_string: UndoTaskAction::get_command_description(),
                        },
                    );
                }
            }
        }

        map
    }

    pub fn from(s: &str) -> ActionType {
        let dict = ActionType::as_dict();
        for (key, value) in dict {
            if value.parsed_string.contains(&s.to_string()) {
                return key;
            }
        }

        unreachable!("Invalid string '{}' for ActionType", &s);
    }

    fn get_command_descriptions() -> HashMap<String, String> {
        let action_type_dict = ActionType::as_dict();
        let mut action_descriptions: HashMap<String, String> = HashMap::new();

        for (action_type, data) in &action_type_dict {
            action_descriptions.insert(
                action_type.to_string(),
                data.documentation_string.to_string(),
            );
        }

        action_descriptions
    }

    pub fn get_action_from_name(name: &str) -> Box<dyn TaskAction> {
        match ActionType::from(name) {
            ActionType::Add => Box::new(AddTaskAction::default()),
            ActionType::Annotate => Box::new(AnnotateTaskAction::default()),
            ActionType::Command => Box::new(CmdTaskAction::default()),
            ActionType::Delete => Box::new(DeleteTaskAction::default()),
            ActionType::Done => Box::new(DoneTaskAction::default()),
            ActionType::Edit => Box::new(EditTaskAction::default()),
            ActionType::Export => Box::new(ExportTaskAction::default()),
            ActionType::Help => Box::new(HelpTaskAction {
                base: BaseTaskAction::default(),
                command_descriptions: Self::get_command_descriptions(),
            }),
            ActionType::Info => Box::new(InfoTaskAction::default()),
            ActionType::List => Box::new(ListTaskAction::default()),
            ActionType::Modify => Box::new(ModifyTaskAction::default()),
            ActionType::Start => Box::new(StartTaskAction::default()),
            ActionType::Stop => Box::new(StopTaskAction::default()),
            ActionType::Undo => Box::new(UndoTaskAction::default()),
        }
    }
}
