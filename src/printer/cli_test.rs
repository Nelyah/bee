#[cfg(test)]
use super::*;

#[allow(unused_imports)]
use chrono::Duration;

#[test]
fn test_format_relative_time() {
    let now = Local::now();

    let tests = vec![
        ("Just Now", now - Duration::seconds(30), "30s"),
        ("Seconds Ago", now - Duration::seconds(45), "45s"),
        ("One Minute Ago", now - Duration::minutes(1), "1m"),
        ("Minutes Ago", now - Duration::minutes(45), "45m"),
        ("One Hour Ago", now - Duration::hours(1), "1h"),
        ("Hours Ago", now - Duration::hours(10), "10h"),
        ("One Day Ago", now - Duration::hours(24), "1d"),
        ("Days Ago", now - Duration::days(6), "6d"),
        ("One Week Ago", now - Duration::days(8), "8d"),
        ("Weeks Ago", now - Duration::days(15), "2w"),
        ("One Month Ago", now - Duration::days(35), "5w"),
        ("Months Ago", now - Duration::days(60), "2mo"),
        ("One Year Ago", now - Duration::days(365), "1y"),
        ("Years Ago", now - Duration::days(730), "2y"),
    ];

    for (name, input, expected) in tests {
        let got = format_relative_time(input);
        assert_eq!(expected, got, "Failed test for {}", name);
    }
}
