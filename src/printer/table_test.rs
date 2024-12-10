#[allow(unused_imports)]
use std::io::{self, BufWriter, Write};

#[cfg(test)]
use super::*;

pub struct MockWriter {
    pub data: Vec<u8>, // Store written data here for inspection
}

impl MockWriter {
    #[allow(dead_code)]
    pub fn new() -> MockWriter {
        MockWriter { data: Vec::new() }
    }
}

// Implement the Write trait for MockWriter
impl Write for MockWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.data.extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[test]
fn test_table() {
    let mock_writer = Box::new(MockWriter::new());
    let cell_text = "test dflaasdf dashf asf u awefaw faw af a".to_string();

    let mut wrapped = wrap_text(&cell_text, 30);
    let new_line_count = wrapped.chars().filter(|&c| c == '\n').count();
    assert_eq!(new_line_count, 1);
    wrapped = wrap_text("", 30);
    assert_eq!(wrapped.chars().filter(|&c| c == '\n').count(), 0);
    wrapped = wrap_text("asd asd asd ", 2);
    assert_eq!(wrapped.chars().filter(|&c| c == '\n').count(), 2);

    let headers: Vec<String> = vec!["hey".to_string(), "you".to_string()];
    let mut t = Table::new(&headers, BufWriter::new(mock_writer)).unwrap();

    t.max_width = 30;
    let _ = t
        .add_row(vec!["again".to_string(), cell_text], None)
        .unwrap();

    t.print();
    let content = String::from_utf8(t.writer.into_parts().1.unwrap()).unwrap();
    assert_eq!(content.chars().filter(|&c| c == '\n').count(), 4);
}
