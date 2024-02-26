use colored::{ColoredString, Colorize, Styles};
use std::io::{BufWriter, Write};

#[derive(Clone)]
pub struct StyledText {
    styles: Vec<Styles>,
    background_color: Option<(u8, u8, u8)>, // RGB
    foreground_color: Option<(u8, u8, u8)>, // RGB
}

impl StyledText {
    // Function to apply the style to a string
    pub fn apply(&self, text: &str) -> ColoredString {
        let mut coloured: ColoredString = ColoredString::from(text);
        if let Some(bg) = self.background_color {
            coloured = coloured.on_truecolor(bg.0, bg.1, bg.2);
        }
        if let Some(fg) = self.foreground_color {
            coloured = coloured.truecolor(fg.0, fg.1, fg.2);
        }
        for s in self.styles.iter() {
            match s {
                Styles::Clear => (),
                Styles::Hidden => {
                    coloured = coloured.hidden();
                }
                Styles::Reversed => coloured = coloured.reversed(),
                Styles::Bold => {
                    coloured = coloured.bold();
                }
                Styles::Strikethrough => coloured = coloured.strikethrough(),
                Styles::Italic => coloured = coloured.italic(),
                Styles::Dimmed => coloured = coloured.dimmed(),
                Styles::Underline => coloured = coloured.underline(),
                Styles::Blink => coloured = coloured.blink(),
            }
        }
        coloured
    }
}

pub struct Table<W: Write> {
    column_padding: usize,
    columns: Vec<String>,
    rows: Vec<Vec<String>>,
    column_widths: Vec<usize>,
    writer: BufWriter<W>,
    max_width: usize,
    alternating_colours: bool,
    primary_style: StyledText,
    secondary_style: StyledText,
    header_style: StyledText,
}

impl<W: Write> Table<W> {
    pub fn new(column_headers: &Vec<String>, writer: W) -> Result<Table<W>, &'static str> {
        if column_headers.is_empty() {
            return Err("table must have at least one column");
        }

        let column_widths = column_headers.iter().map(|header| header.len()).collect();

        Ok(Table {
            column_padding: 2,
            columns: column_headers.to_owned(),
            rows: Vec::new(),
            column_widths,
            writer: BufWriter::new(writer),
            max_width: get_terminal_width(),
            alternating_colours: true,
            primary_style: StyledText {
                styles: vec![],
                background_color: Some((89, 89, 89)),
                foreground_color: Some((220, 220, 220)),
            },
            secondary_style: StyledText {
                styles: vec![],
                background_color: Some((38, 38, 38)),
                foreground_color: Some((220, 220, 220)),
            },
            header_style: StyledText {
                styles: vec![Styles::Underline, Styles::Bold],
                background_color: None,
                foreground_color: Some((255, 255, 255)),
            },
        })
    }

    pub fn add_row(&mut self, row: Vec<String>) -> Result<&mut Self, &'static str> {
        if row.len() != self.columns.len() {
            return Err("row length does not match column length");
        }

        for (i, cell) in row.iter().enumerate() {
            if cell.len() > self.column_widths[i] {
                self.column_widths[i] = cell.len();
            }
        }

        self.rows.push(row);
        Ok(self)
    }

    pub fn print(&mut self) {
        self.update_column_width();
        self.adjust_column_widths();

        let mut header = String::new();
        for (i, col) in self.columns.iter().enumerate() {
            header.push_str(&format!("{:<width$}", col, width = self.column_widths[i]));
            header.push_str(&" ".repeat(self.column_padding));
        }

        writeln!(self.writer, "{}", self.header_style.apply(&header)).unwrap();

        let primary_style = self.primary_style.clone();
        let secondary_style = self.secondary_style.clone();

        for i in 0..self.rows.len() {
            if self.alternating_colours && i % 2 == 1 {
                self.print_row(i, &primary_style.clone());
            } else {
                self.print_row(i, &secondary_style.clone());
            }
        }
    }

    fn print_row(&mut self, row_index: usize, color_style: &StyledText) {
        let mut wrapped_cells: Vec<Vec<String>> = Vec::new();
        let mut max_height = 1;

        for (i, cell) in self.rows[row_index].iter().enumerate() {
            let wrapped_cell = wrap_text(cell, self.column_widths[i]);
            let new_line_count = wrapped_cell.chars().filter(|&c| c == '\n').count();

            max_height = max_height.max(new_line_count + 1);
            wrapped_cells.push(wrapped_cell.split('\n').map(String::from).collect());
        }

        for j in 0..max_height {
            let mut line = String::new();
            for (i, wrapped_cell) in wrapped_cells.iter().enumerate() {
                let empty_str = "".to_string();
                let out_str = wrapped_cell.get(j).unwrap_or(&empty_str);
                line += &format!(
                    "{:<width$}{}",
                    out_str,
                    " ".repeat(self.column_padding),
                    width = self.column_widths[i]
                );
            }
            // Assume color_style is a function or closure that applies a style to the string
            writeln!(self.writer, "{}", color_style.apply(&line)).unwrap();
        }
    }

    fn adjust_column_widths(&mut self) {
        let mut max_column_width = 0;
        let mut max_column_id = 0;
        let mut sum_width = 0;

        for (i, &col_width) in self.column_widths.iter().enumerate() {
            sum_width += col_width;
            if col_width > max_column_width {
                max_column_width = col_width;
                max_column_id = i;
            }
        }

        sum_width += self.columns.len() * self.column_padding;
        if sum_width >= self.max_width {
            let need_to_reduce = sum_width - self.max_width;

            if max_column_width < need_to_reduce {
                panic!("There is a bug (hack) in the Table::print function");
            }

            self.column_widths[max_column_id] -=
                need_to_reduce + self.columns.len() * self.column_padding;
        }
    }

    fn update_column_width(&mut self) {
        for row in &self.rows {
            for (i, cell) in row.iter().enumerate() {
                let cell_length = cell.chars().count();
                if cell_length > self.column_widths[i] {
                    self.column_widths[i] = cell_length;
                }
            }
        }
    }
}

fn get_terminal_width() -> usize {
    term_size::dimensions().map_or(80, |(w, _)| w)
}

fn wrap_text(text: &str, width: usize) -> String {
    if text.len() <= width {
        return text.to_string();
    }

    let mut wrapped_text = String::new();
    let mut line_length = 0;

    for word in text.split_whitespace() {
        if line_length + word.len() + 1 > width {
            wrapped_text.push('\n');
            line_length = 0;
        }
        wrapped_text.push_str(word);
        wrapped_text.push(' ');
        line_length += word.len() + 1;
    }

    wrapped_text.trim().to_string()
}

#[path = "table_test.rs"]
mod table_test;
