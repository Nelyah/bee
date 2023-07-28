use crate::task::{Task, TaskStatus};
use std::str::FromStr;
use uuid::Uuid;

use std::collections::HashMap;

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

pub struct FilterView {
    views: HashMap<String, Filter>,
}

impl FilterView {
    pub fn iter(&self) -> impl Iterator<Item = (&String, &Filter)> {
        return self.views.iter();
    }

    pub fn values(&self) -> impl Iterator<Item = &Filter> {
        return self.views.values();
    }

    pub fn get_view(&self, name: &str) -> Filter {
        if let Some(filter) = self.views.get(name) {
            return filter.clone();
        }
        panic!("Error: unknown filter view: {}", name);
    }
}

impl Default for FilterView {
    fn default() -> FilterView {
        Self {
            views: HashMap::from([
                (
                    "pending".to_owned(),
                    Filter {
                        has_value: true,
                        value: "status:pending".to_owned(),
                        operator: FilterCombinationType::And,
                        ..Default::default()
                    },
                ),
                (
                    "completed".to_owned(),
                    Filter {
                        has_value: true,
                        value: "status:completed".to_owned(),
                        operator: FilterCombinationType::And,
                        ..Default::default()
                    },
                ),
                (
                    "deleted".to_owned(),
                    Filter {
                        has_value: true,
                        value: "status:deleted".to_owned(),
                        operator: FilterCombinationType::And,
                        ..Default::default()
                    },
                ),
                (
                    "all".to_owned(),
                    Filter {
                        has_value: false,
                        operator: FilterCombinationType::And,
                        ..Default::default()
                    },
                ),
            ]),
        }
    }
}

fn split_out_parenthesis(values: &[String]) -> Vec<String> {
    let mut result_string = Vec::new();
    for token in values {
        let mut tmp_token = token.clone();
        if token.starts_with('(') && tmp_token.len() > 1 {
            result_string.push("(".to_owned());
            tmp_token = tmp_token[1..].to_owned();
        }

        if tmp_token.ends_with(')') && tmp_token.len() > 1 {
            result_string.push(tmp_token[..tmp_token.len() - 1].to_owned());
            result_string.push(")".to_owned());
        } else {
            result_string.push(tmp_token.to_owned());
        }
    }
    result_string
}

fn group_by_filter(input_filters: &[Filter], filter_type: FilterCombinationType) -> Vec<Filter> {
    let mut temp_filter_slice = Vec::new();
    let mut idx = 0;
    while idx < input_filters.len() {
        if input_filters[idx].operator < filter_type || !input_filters[idx].childs.is_empty() {
            let mut current_chunk = Vec::new();
            current_chunk.push(input_filters[idx].clone());
            let mut look_ahead_idx = idx + 1;
            while look_ahead_idx < input_filters.len() {
                if input_filters[look_ahead_idx].operator < filter_type
                    || !input_filters[look_ahead_idx].childs.is_empty()
                {
                    current_chunk.push(input_filters[look_ahead_idx].clone());
                } else if input_filters[look_ahead_idx].operator > filter_type
                    && input_filters[look_ahead_idx].childs.is_empty()
                {
                    break;
                }
                look_ahead_idx += 1;
            }
            idx = look_ahead_idx;

            if current_chunk.len() > 1 {
                temp_filter_slice.push(Filter {
                    operator: filter_type.clone(),
                    childs: current_chunk,
                    ..Default::default()
                });
            } else {
                temp_filter_slice.push(current_chunk[0].clone());
            }
        } else {
            temp_filter_slice.push(input_filters[idx].clone());
            idx += 1;
        }
    }

    temp_filter_slice
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
        if let Ok(status) = TaskStatus::from_str(status_as_str) {
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

pub fn build_filter_from_strings(values: &[String]) -> Filter {
    if values.is_empty() {
        return Filter::default();
    }

    let temporary_numbers_only_filter = values
        .iter()
        .map(|v| i32::from_str(v))
        .take_while(|res| res.is_ok())
        .map(|res| res.unwrap())
        .map(|v| Filter {
            has_value: true,
            value: v.to_string(),
            ..Default::default()
        })
        .collect::<Vec<_>>();

    if temporary_numbers_only_filter.len() == values.len() {
        return Filter {
            operator: FilterCombinationType::Or,
            childs: temporary_numbers_only_filter,
            ..Default::default()
        };
    }

    let values = split_out_parenthesis(values);

    let mut filters_slice = Vec::new();
    let mut opening_parenthesis = 0;
    let mut closing_parenthesis = 0;
    let mut is_set_opening_parenthesis = false;
    let mut is_set_closing_parenthesis = false;

    let mut idx = 0;
    while idx < values.len() {
        let token = &values[idx];
        match token.as_str() {
            "and" => filters_slice.push(Filter {
                operator: FilterCombinationType::And,
                ..Default::default()
            }),
            "or" => filters_slice.push(Filter {
                operator: FilterCombinationType::Or,
                ..Default::default()
            }),
            "xor" => filters_slice.push(Filter {
                operator: FilterCombinationType::Xor,
                ..Default::default()
            }),
            _ => {
                filters_slice.push(Filter {
                    operator: FilterCombinationType::None,
                    value: token.clone(),
                    has_value: true,
                    ..Default::default()
                });

                if token == "(" && !is_set_opening_parenthesis {
                    is_set_opening_parenthesis = true;
                    opening_parenthesis = idx;
                } else if token == ")" && !is_set_closing_parenthesis {
                    is_set_closing_parenthesis = true;
                    closing_parenthesis = idx;
                }
            }
        }
        idx += 1;
    }

    if is_set_opening_parenthesis && is_set_closing_parenthesis {
        let f = build_filter_from_strings(&values[opening_parenthesis + 1..closing_parenthesis]);
        let mut new_filters_slice = filters_slice[..opening_parenthesis].to_owned();
        new_filters_slice.push(f);
        if closing_parenthesis + 1 < filters_slice.len() {
            new_filters_slice.extend_from_slice(&filters_slice[closing_parenthesis + 1..]);
        }
        filters_slice = new_filters_slice;
    }

    filters_slice = group_by_filter(&filters_slice, FilterCombinationType::And);
    filters_slice = group_by_filter(&filters_slice, FilterCombinationType::Or);
    filters_slice = group_by_filter(&filters_slice, FilterCombinationType::Xor);

    filters_slice[0].clone()
}
