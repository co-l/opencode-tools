# agents

Utilities for installing OpenCode agents and related commands.

## CodeHealth

Install or remove a global `@CodeHealth` subagent and `/health` command.

```bash
# install
./CodeHealth.sh

# uninstall
./CodeHealth.sh uninstall
```

Optional environment variables:

- `OPENCODE_CONFIG_DIR` to override the target config path
- `CODEHEALTH_MODEL` to override the default model (`openai/gpt-5.3-codex`)
