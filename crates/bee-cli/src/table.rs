use colored::{ColoredString, Colorize, Styles};
use log::{debug, trace};
use regex::Regex;
use std::{cmp::max, io::Write};
use terminal_size::{Width, terminal_size};
use unicode_segmentation::UnicodeSegmentation;

use crate::config::get_cli_config;

/// Get the number of actual characters in a string, where
/// 1 character = 1 grapheme
fn get_str_len(value: &str) -> usize {
    value.graphemes(true).count()
}

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

#[derive(Default)]
struct Section {
    name: String,
    rows: Vec<Vec<String>>,
    row_styles: Vec<Option<StyledText>>,
}

impl Section {
    pub fn add_row(
        &mut self,
        row: Vec<String>,
        style: Option<StyledText>,
    ) -> Result<&mut Self, &'static str> {
        self.rows.push(row);
        self.row_styles.push(style);
        Ok(self)
    }
}

pub struct Table<W: Write> {
    column_padding: usize,
    columns: Vec<String>,
    sections: Vec<Section>,
    column_widths: Vec<usize>,
    writer: W,
    max_width: usize,
    alternating_colours: bool,
    primary_style: StyledText,
    secondary_style: StyledText,
    section_palette: Vec<(u8, u8, u8)>,
    section_style: StyledText,
    section_default_style: StyledText,
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

        let conf = get_cli_config();
        // let mut section_colour_palette = vec![];
        // section_colour_palette = conf.section.colour_palette.clone();

        Ok(Table {
            column_padding: 1,
            columns: column_headers.to_owned(),
            sections: Vec::new(),
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
            section_palette: conf.section.colour_palette.clone(),
            section_default_style: StyledText {
                styles: vec![],
                background_color: Some(conf.section.default_section_colour),
                foreground_color: None,
            },
            section_style: StyledText {
                styles: vec![Styles::Bold],
                background_color: Some(conf.section.section_header_bg),
                foreground_color: Some((199, 199, 199)),
            },
            header_style: StyledText {
                styles: vec![Styles::Underline],
                background_color: None,
                foreground_color: Some((199, 199, 199)),
            },
        })
    }

    pub fn add_section(&mut self, section_name: String) {
        debug!("Added new section in table: {}", section_name);
        self.sections.push(Section {
            name: section_name,
            ..Default::default()
        });
    }

    pub fn add_row(
        &mut self,
        row: Vec<String>,
        style: Option<StyledText>,
    ) -> Result<&mut Self, &'static str> {
        if row.len() != self.columns.len() {
            return Err("row length does not match column length");
        }

        if self.sections.is_empty() {
            self.sections.push(Section::default());
        }

        let _ = self.sections.last_mut().unwrap().add_row(row, style);
        Ok(self)
    }

    fn get_total_row_length(&self) -> usize {
        let mut line_total_length: usize = self.column_widths.iter().sum();
        line_total_length += self.column_padding * (self.column_widths.len());
        line_total_length
    }

    fn print_empty_line(&mut self, palette_style: Option<&StyledText>) {
        let mut row_length = self.get_total_row_length();
        let section_column = if let Some(p_style) = palette_style {
            row_length += 1;
            p_style.apply(" ").to_string()
        } else {
            // 2 being the usual section header length
            row_length += 2;
            "".to_string()
        };

        let filler_space_raw = &" ".repeat(row_length);
        let filler_space = if palette_style.is_some() {
            self.section_style.apply(filler_space_raw).to_string()
        } else {
            filler_space_raw.to_string()
        };

        writeln!(self.writer, "{}{}", section_column, filler_space,).unwrap();
    }

    // Check whether we have multiple sections, or if not, if the one we have is just
    // a placeholder
    fn has_section(&self) -> bool {
        if self.sections.len() > 1 {
            return true;
        }
        if self.sections.is_empty() {
            return false;
        }
        !self.sections.last().unwrap().name.is_empty()
    }

    pub fn print(&mut self) {
        self.update_column_width_state();
        self.add_padding_to_column_width();

        if self.has_section() {
            debug!("Table has named sections");
        } else {
            debug!("Table does NOT have named sections");
        }

        let mut header = if self.has_section() {
            "  ".to_string()
        } else {
            "".to_string()
        };
        for (i, col) in self.columns.iter().enumerate() {
            header.push_str(&format!("{:<width$}", col, width = self.column_widths[i]));
            header.push_str(&" ".repeat(self.column_padding));
        }

        writeln!(self.writer, "{}", self.header_style.apply(&header)).unwrap();

        for section_idx in 0..self.sections.len() {
            self.print_section(section_idx);
        }
    }

    fn print_section(&mut self, section_idx: usize) {
        let section_title = &self.sections[section_idx].name;
        let palette_style_bg = if section_title.is_empty() {
            self.section_default_style.background_color
        } else if self.section_palette.is_empty() {
            None
        } else {
            Some(self.section_palette[section_idx % self.section_palette.len()])
        };
        let palette_style = StyledText {
            background_color: palette_style_bg,
            foreground_color: None,
            styles: vec![],
        };

        {
            let section_column = if self.has_section() {
                if section_idx != 0 {
                    self.print_empty_line(None);
                }
                format!("{} ", palette_style.apply(" "))
            } else {
                "".to_string()
            };
            let section_title = &self.sections[section_idx].name;
            if !section_title.is_empty() {
                writeln!(
                    self.writer,
                    "{}",
                    self.section_style.apply(&format!(
                        "{}{}{}",
                        section_column,
                        section_title,
                        " ".repeat(
                            self.get_total_row_length()
                                .saturating_sub(section_title.len())
                        )
                    ))
                )
                .unwrap();
            }
        }
        if self.has_section() {
            self.print_empty_line(Some(&palette_style.clone()));
        }

        let palette_style_opt = if self.has_section() {
            Some(&palette_style)
        } else {
            None
        };

        for row_idx in 0..self.sections[section_idx].rows.len() {
            let style = self.sections[section_idx].row_styles[row_idx].to_owned();
            match style {
                Some(style) => {
                    if self.alternating_colours && row_idx % 2 == 1 {
                        self.print_row(
                            section_idx,
                            row_idx,
                            &overwrite_style(style.to_owned(), &self.primary_style),
                            palette_style_opt,
                        );
                    } else {
                        self.print_row(
                            section_idx,
                            row_idx,
                            &overwrite_style(style.to_owned(), &self.secondary_style),
                            palette_style_opt,
                        );
                    }
                }
                None => {
                    if self.alternating_colours && row_idx % 2 == 1 {
                        self.print_row(
                            section_idx,
                            row_idx,
                            &self.primary_style.clone(),
                            palette_style_opt,
                        );
                    } else {
                        self.print_row(
                            section_idx,
                            row_idx,
                            &self.secondary_style.clone(),
                            palette_style_opt,
                        );
                    }
                }
            }
        }
        debug!(
            "Printed section name={}, idx={}",
            self.sections[section_idx].name, section_idx
        );
    }

    fn print_row(
        &mut self,
        section_index: usize,
        row_index: usize,
        color_style: &StyledText,
        palette_style: Option<&StyledText>,
    ) {
        let mut wrapped_cells: Vec<Vec<String>> = Vec::new();
        let mut max_height = 1;

        let section_column = if let Some(p_style) = palette_style {
            format!("{} ", p_style.apply(" ")).to_string()
        } else {
            "".to_string()
        };

        for (i, cell) in self.sections[section_index].rows[row_index]
            .iter()
            .enumerate()
        {
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
            writeln!(
                self.writer,
                "{}{}",
                section_column,
                color_style.apply(&line)
            )
            .unwrap();
        }
    }

    fn add_padding_to_column_width(&mut self) {
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

    fn update_column_width_state(&mut self) {
        for section in &self.sections {
            for row in &section.rows {
                for (i, cell) in row.iter().enumerate() {
                    let cell_width = get_max_width_of_cell(cell);
                    if cell_width > self.column_widths[i] {
                        self.column_widths[i] = cell_width;
                    }
                }
            }
        }
    }
}

/// Return the size of longest line in parameter cell.
///
/// Lines are separated by the '\n' character.
fn get_max_width_of_cell(cell: &str) -> usize {
    cell.split('\n').map(get_str_len).max().unwrap_or(0)
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
    if let Some((Width(w), _)) = terminal_size() {
        w.into()
    } else {
        80
    }
}

fn wrap_text(text: &str, width: usize) -> String {
    trace!("Starting to wrap '{}' with width {}", text, width);
    trace!("Original text has .len() {}", text.len());
    trace!("Original text has {} graphemes", get_str_len(text));
    let date_regex = Regex::new(r"\d{4}-\d{2}-\d{2}").unwrap();

    if get_max_width_of_cell(text) <= width {
        trace!("Text fits in the width of the cell");
        return text.to_string();
    }

    let mut wrapped_text = String::new();
    let mut line_length = 0;
    let mut newline_str = "\n";

    // Go over every word split on space, not \n
    for outer_word in split_most_whitespaces(text) {
        trace!("outer_word is {}", outer_word);
        let mut first = true;

        // If there is a word that contains one (or more) newline(s), go over each
        for word in outer_word.split('\n') {
            // HACK: If we notice a date, the following lines (but not this one) will be indented
            // The reason is that for most (all?) cases, this happens with annotations
            // and having the rest of the annotation indent is nicer. Not sure whether this
            // can have more side effects.
            // This also assumes that there are only annotations coming below the first annotation
            if date_regex.is_match(word) {
                newline_str = "\n";
            }

            // The word that comes after a \n
            if !first {
                wrapped_text.push_str(newline_str);
                line_length = 0;
                trace!("We inserted newline before the word");
            }
            first = false;

            // If this goes over width
            if line_length + get_str_len(word) + 1 > width {
                wrapped_text.push_str(newline_str);
                trace!(
                    "We inserted newline before the word because line_length {} \
                    and word is '{}' and word grapheme len is {}",
                    line_length,
                    word,
                    get_str_len(word)
                );
                line_length = max(0, newline_str.len());
            }
            wrapped_text.push_str(word);
            wrapped_text.push(' ');
            line_length += get_str_len(word) + 1;

            // Set the indent after we've seen a date
            if date_regex.is_match(word) {
                newline_str = "\n              ";
            }
        }
    }

    wrapped_text.trim().to_string()
}

#[path = "table_test.rs"]
mod table_test;
