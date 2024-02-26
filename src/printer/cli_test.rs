#[cfg(test)]
use super::*;

#[allow(unused_imports)]
use chrono::Duration;

#[test]
fn test_format_relative_time() {
    let now = Local::now();

    let tests = vec![
        ("Just Now", now - Duration::try_seconds(30).unwrap(), "30s"),
        (
            "Seconds Ago",
            now - Duration::try_seconds(45).unwrap(),
            "45s",
        ),
        (
            "One Minute Ago",
            now - Duration::try_minutes(1).unwrap(),
            "1m",
        ),
        (
            "Minutes Ago",
            now - Duration::try_minutes(45).unwrap(),
            "45m",
        ),
        ("One Hour Ago", now - Duration::try_hours(1).unwrap(), "1h"),
        ("Hours Ago", now - Duration::try_hours(10).unwrap(), "10h"),
        ("One Day Ago", now - Duration::try_hours(24).unwrap(), "1d"),
        ("Days Ago", now - Duration::try_days(6).unwrap(), "6d"),
        ("One Week Ago", now - Duration::try_days(8).unwrap(), "8d"),
        ("Weeks Ago", now - Duration::try_days(15).unwrap(), "2w"),
        ("One Month Ago", now - Duration::try_days(35).unwrap(), "5w"),
        ("Months Ago", now - Duration::try_days(60).unwrap(), "2mo"),
        ("One Year Ago", now - Duration::try_days(365).unwrap(), "1y"),
        ("Years Ago", now - Duration::try_days(730).unwrap(), "2y"),
    ];

    for (name, input, expected) in tests {
        let got = format_relative_time(input);
        assert_eq!(expected, got, "Failed test for {}", name);
    }
}
