use super::task::{Task,TaskStatus};
use uuid::Uuid;

#[path = "filters_test.rs"]
mod filters_test;

#[derive(Clone, Debug, PartialEq, PartialOrd)]
enum FilterCombinationType {
    None,
    And,
    Or,
    Xor,
}

impl Default for FilterCombinationType {
    fn default() -> Self {
        FilterCombinationType::None
    }
}

#[derive(Clone, Default)]
pub struct Filter {
    pub has_value: bool,
    pub value: String,
    operator: FilterCombinationType,
    childs: Vec<Filter>,
}

impl PartialEq for Filter {
    fn eq(&self, other: &Self) -> bool {
        if self.has_value != other.has_value
            || self.value != other.value
            || self.childs.len() != other.childs.len()
        {
            false
        } else if self.childs.len() == 0 {
            true
        } else if self.operator != other.operator {
            false
        } else {
            self.childs == other.childs
        }
    }
}

impl Filter {
    pub fn to_string(&self) -> String {
        self.to_string_impl("")
    }

    fn to_string_impl(&self, indent: &str) -> String {
        let str_op = match self.operator {
            FilterCombinationType::And => "AND",
            FilterCombinationType::Or => "OR",
            FilterCombinationType::Xor => "XOR",
            FilterCombinationType::None => "NONE",
        };
        let mut out_str = String::default();

        if self.has_value {
            out_str = out_str
                + "\n"
                + &format!(
                    "{}Operator is {} (has_value: {}, value: \"{}\")",
                    indent, str_op, self.has_value, self.value
                );
        } else {
            out_str = out_str + "\n" + &format!("{}Operator is {}", indent, str_op);
        }

        for c in &self.childs {
            out_str = out_str + &c.to_string_impl(&(indent.to_owned() + "    "));
        }
        out_str
    }

    pub fn and(self, other: Filter) -> Self {
        Filter {
            has_value: false,
            operator: FilterCombinationType::And,
            childs: vec![self, other],
            ..Default::default()
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = &Filter> {
        std::iter::once(self).chain(self.childs.iter())
    }
}

impl std::fmt::Debug for Filter {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.to_string())
    }
}

fn task_matches_filter(t: &Task, f: &Filter) -> bool {
    let filter_uuid = Uuid::parse_str(&f.value);
    if let Ok(parsed_uuid) = filter_uuid {
        if parsed_uuid == t.uuid {
            return true;
        }
    }

    let filter_id = f.value.parse::<usize>();
    if let Ok(parsed_id) = filter_id {
        if let Some(id_value) = t.id {
            if parsed_id == id_value {
                return true;
            }
            return false;
        }
        return false;
    }

    if f.value.starts_with("status:") {
        return task_matches_status_filter(t, f);
    }

    if t.description
        .to_lowercase()
        .contains(&f.value.to_lowercase())
    {
        return true;
    }

    false
}

fn task_matches_status_filter(t: &Task, f: &Filter) -> bool {
    if let Some(status_as_str) = f.value.strip_prefix("status:") {
        if let Ok(status) = TaskStatus::from_string(status_as_str) {
            return t.status == status;
        }
    }

    false
}

pub fn validate_task(t: &Task, f: &Filter) -> bool {
    match f.operator {
        FilterCombinationType::None => {
            if !f.has_value {
                return true;
            }
            if task_matches_filter(t, f) {
                return true;
            }
            false
        }
        FilterCombinationType::And => {
            if f.has_value && !task_matches_filter(t, f) {
                return false;
            }
            for fc in &f.childs {
                if !validate_task(t, fc) {
                    return false;
                }
            }
            true
        }
        FilterCombinationType::Or => {
            if f.has_value && task_matches_filter(t, f) {
                return true;
            }
            for fc in &f.childs {
                if validate_task(t, fc) {
                    return true;
                }
            }
            false
        }
        FilterCombinationType::Xor => {
            let mut count_true = 0;
            if f.has_value && task_matches_filter(t, f) {
                count_true += 1;
            }
            for fc in &f.childs {
                if validate_task(t, fc) {
                    count_true += 1;
                }
            }
            count_true == 1
        }
    }
}

