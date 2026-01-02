# Token Optimization Patterns

Patterns for reducing token usage in this codebase.

## Use the Explore Agent for Reconnaissance

**When:** Open-ended questions like "where is X handled?", "how does Y work?", "find all places that do Z"

**Instead of:** Multiple Grep/Read cycles in the main conversation

**Example:**
```
BAD: Multiple Grep calls → Read files → More Grep → More Read (all in main context)
GOOD: Task(subagent_type="Explore", prompt="Find where the 'a' keybind is handled in detail mode")
```

The Explore agent keeps the search-and-read cycle in a separate context, returning only the answer.

## Use Line-Limited Reads

**When:** You know approximately where content is in a file

**Instead of:** `Read(file_path)` (entire file)
**Use:** `Read(file_path, offset=400, limit=40)` (just the relevant section)

**How to find line numbers:**
1. First use Grep with `-n` to find line numbers: `Grep(pattern, path, output_mode="content", -n=true)`
2. Then read only the section you need: `Read(file_path, offset=line-10, limit=50)`

## Use Serena Symbolic Tools

**When:** Searching for code symbols (classes, functions, methods)

**Instead of:** `Grep(pattern)` followed by `Read(file)`
**Use:** `mcp__serena__find_symbol(name_path_pattern, include_body=true)`

The symbolic tools understand code structure and return just what you need.

## File Size Awareness

Before reading a file, consider:
- Is it a small config file (~100 lines)? → Read entire file
- Is it a large source file (~600+ lines)? → Use line-limited read
- Test files often large → Use line-limited read after Grep to find test location
