# timer

Show agent thinking time and token stats for opencode sessions.

## Requirements

- **opencode v1.2.0+** (uses SQLite storage)
- **sqlite3** CLI tool

```bash
# Debian/Ubuntu
sudo apt install sqlite3

# macOS (usually pre-installed)
brew install sqlite3

# Arch
sudo pacman -S sqlite
```

> For opencode versions < v1.2.0 (JSON storage), use [timer v1.0.0](https://github.com/sst/opencode-plugins/tree/timer-v1.0.0/timer)

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
00:18:52  10 prompts  Session title
         output: 56,161  (49 tok/s)
         (2026-02-15 11:39)
```

- **Time**: Agent thinking time (excludes waiting for user input)
- **Prompts**: Number of user messages
- **Output**: Tokens generated (response + reasoning)
- **tok/s**: Generation speed

## Verbose mode

```
timer -v
```

Shows detailed breakdown:

```
00:18:57  10 prompts  Session title

         OUTPUT
           tokens:    56,262
           speed:     49 tok/s

         CONTEXT
           size:      143,732
           cached:    99%
           rebuilds:  4
         (2026-02-15 11:39)
```

- **OUTPUT**: Total tokens generated and speed
- **CONTEXT**: Current context window size and cache efficiency
- **rebuilds**: Cache invalidations (TTL expiry, costs extra)
