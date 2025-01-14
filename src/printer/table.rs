use colored::{ColoredString, Colorize, Styles};
use log::debug;
use std::io::Write;

use crate::config::get_config;

#[derive(Clone)]
pub struct StyledText {
    pub styles: Vec<Styles>,
    pub background_color: Option<(u8, u8, u8)>, // RGB
    pub foreground_color: Option<(u8, u8, u8)>, // RGB
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
    row_styles: Vec<Option<StyledText>>,
    rows: Vec<Vec<String>>,
    column_widths: Vec<usize>,
    writer: W,
    max_width: usize,
    alternating_colours: bool,
    primary_style: StyledText,
    secondary_style: StyledText,
    header_style: StyledText,
}

fn overwrite_style(mut first: StyledText, second: &StyledText) -> StyledText {
    if first.background_color.is_none() {
        first.background_color = second.background_color.to_owned();
    }

    if first.foreground_color.is_none() {
        first.foreground_color = second.foreground_color.to_owned();
    }

    first
}

impl<W: Write> Table<W> {
    pub fn new(column_headers: &Vec<String>, writer: W) -> Result<Table<W>, &'static str> {
        if column_headers.is_empty() {
            return Err("table must have at least one column");
        }

        let column_widths = column_headers.iter().map(|header| header.len()).collect();

        let conf = get_config();

        Ok(Table {
            column_padding: 1,
            columns: column_headers.to_owned(),
            row_styles: Vec::new(),
            rows: Vec::new(),
            column_widths,
            writer,
            max_width: get_terminal_width(),
            alternating_colours: true,
            primary_style: StyledText {
                styles: vec![],
                background_color: Some(conf.get_primary_colour_bg()),
                foreground_color: Some(conf.get_primary_colour_fg()),
            },
            secondary_style: StyledText {
                styles: vec![],
                background_color: Some(conf.get_secondary_colour_bg()),
                foreground_color: Some(conf.get_secondary_colour_fg()),
            },
            header_style: StyledText {
                styles: vec![Styles::Underline],
                background_color: None,
                foreground_color: Some((199, 199, 199)),
            },
        })
    }

    pub fn add_row(
        &mut self,
        row: Vec<String>,
        style: Option<StyledText>,
    ) -> Result<&mut Self, &'static str> {
        if row.len() != self.columns.len() {
            return Err("row length does not match column length");
        }

        for (i, cell) in row.iter().enumerate() {
            let max_line_length = get_max_width_of_cell(cell);
            if max_line_length > self.column_widths[i] {
                self.column_widths[i] = max_line_length;
            }
        }

        self.rows.push(row);
        self.row_styles.push(style);
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
            let style = self.row_styles[i].to_owned();
            match style {
                Some(style) => {
                    if self.alternating_colours && i % 2 == 1 {
                        self.print_row(i, &overwrite_style(style.to_owned(), &primary_style));
                    } else {
                        self.print_row(i, &overwrite_style(style.to_owned(), &secondary_style));
                    }
                }
                None => {
                    if self.alternating_colours && i % 2 == 1 {
                        self.print_row(i, &primary_style.clone());
                    } else {
                        self.print_row(i, &secondary_style.clone());
                    }
                }
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
                let cell_width = get_max_width_of_cell(cell);
                if cell_width > self.column_widths[i] {
                    self.column_widths[i] = cell_width;
                }
            }
        }
    }
}

/// Return the size of longest line in parameter cell.
///
/// Lines are separated by the '\n' character.
fn get_max_width_of_cell(cell: &str) -> usize {
    cell.split('\n').map(|line| line.len()).max().unwrap_or(0)
}

// This does the same as `split_whitespace` but ignores '\n' chars
fn split_most_whitespaces(input: &str) -> Vec<String> {
    let mut output = Vec::default();

    let mut buffer = String::default();
    let mut is_after_newline = false;
    for c in input.chars() {
        if c.is_whitespace() && c != '\n' && !is_after_newline && !buffer.is_empty() {
            output.push(buffer);
            buffer = String::default();
            continue;
        }

        is_after_newline = c.is_whitespace();
        buffer += &c.to_string();
    }
    if !buffer.is_empty() {
        output.push(buffer);
    }

    output
}

fn get_terminal_width() -> usize {
    term_size::dimensions().map_or(80, |(w, _)| w)
}

fn wrap_text(text: &str, width: usize) -> String {
    if get_max_width_of_cell(text) <= width {
        return text.to_string();
    }

    let mut wrapped_text = String::new();
    let mut line_length = 0;

    for outer_word in split_most_whitespaces(text) {
        let mut first = true;
        for word in outer_word.split('\n') {
            if !first {
                wrapped_text.push('\n');
                line_length = 0;
            }
            first = false;
            if line_length + word.len() + 1 > width {
                wrapped_text.push('\n');
                line_length = 0;
            }
            wrapped_text.push_str(word);
            wrapped_text.push(' ');
            line_length += word.len() + 1;
        }
    }

    debug!("{}", wrapped_text);
    wrapped_text.trim().to_string()
}

#[path = "table_test.rs"]
mod table_test;
