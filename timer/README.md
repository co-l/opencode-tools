# timer

Show agent thinking time and token stats for opencode sessions.

## Install

> **Note**: Linux only for now.

```bash
./install.sh
```

## Usage

Inside an opencode session:

```
!timer
```

The `!` prefix runs shell commands within the session context, and the agent sees the output.

Or from any terminal in a directory with an opencode session:

```bash
timer          # compact view
timer -v       # verbose view with explanations
```

## Output

```
00:17:31  27 prompts  Session title
         input:  350,336  output: 35,800  (34 tok/s)
         (2026-02-09 15:25)
```

- **Time**: Agent thinking time (excludes waiting for user input)
- **Prompts**: Number of user messages
- **Input**: Tokens sent (new + written to cache, comparable across compaction)
- **Output**: Tokens generated (response + reasoning)
- **tok/s**: Generation speed

## Verbose mode

```
timer -v
```

Shows detailed breakdown of context, cache hit %, and token categories.
