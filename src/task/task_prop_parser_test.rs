use chrono::{Local, NaiveTime, TimeZone};

use super::*;

fn from_string(value: &str) -> TaskProperties {
    let lexer = Lexer::new(value.to_owned());
    let mut parser = TaskPropertyParser::new(lexer);
    parser.parse_task_properties().unwrap()
}

#[test]
fn test_task_properties_parser() {
    let mut tp = from_string("a new task summary");
    let mut props = TaskProperties {
        summary: Some("a new task summary".to_owned()),
        ..TaskProperties::default()
    };
    assert_eq!(tp, props,);
    tp.set_annotate("foo".to_owned());
    props.annotation = Some("foo".to_owned());
    assert_eq!(tp, props);

    let tp = from_string("a new task summ(ary status:completed");
    let props = TaskProperties {
        summary: Some("a new task summ(ary".to_owned()),
        status: Some(TaskStatus::Completed),
        ..TaskProperties::default()
    };
    assert_eq!(tp, props);

    let tp = from_string("a new task summ(\tary status:  pending project: p.a.b.c");
    let props = TaskProperties {
        summary: Some("a new task summ(\tary".to_owned()),
        status: Some(TaskStatus::Pending),
        project: Some(Project {
            name: "p.a.b.c".to_string(),
        }),
        ..TaskProperties::default()
    };
    assert_eq!(tp, props);

    let tp = from_string("a new task -main summary +foo proj: proj.a.b.c");
    assert_eq!(
        tp,
        TaskProperties {
            summary: Some("a new task summary".to_owned()),
            tags_remove: Some(vec!["main".to_owned()]),
            tags_add: Some(vec!["foo".to_owned()]),
            project: Some(Project {
                name: "proj.a.b.c".to_string()
            }),
            ..TaskProperties::default()
        }
    );

    let tp = from_string("");
    assert_eq!(tp, TaskProperties::default(),);

    let tp = from_string("a new task -main summary +foo proj: proj.a.b.c due: today");
    let now = Local::now();
    let today_start = Local
        .from_local_datetime(
            &now.date_naive()
                .and_time(NaiveTime::from_hms_opt(0, 0, 0).unwrap()),
        )
        .single()
        .unwrap();
    assert_eq!(
        tp,
        TaskProperties {
            summary: Some("a new task summary".to_owned()),
            tags_remove: Some(vec!["main".to_owned()]),
            tags_add: Some(vec!["foo".to_owned()]),
            project: Some(Project {
                name: "proj.a.b.c".to_string()
            }),
            date_due: Some(today_start),
            ..TaskProperties::default()
        }
    );

    let tp = from_string("");
    assert_eq!(tp, TaskProperties::default(),);
}
