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

## CodeReviewer

Install or remove a global `@CodeReviewer` subagent and `/review` command.

```bash
# install
./CodeReviewer.sh

# uninstall
./CodeReviewer.sh uninstall
```

Optional environment variables:

- `OPENCODE_CONFIG_DIR` to override the target config path
- `CODEREVIEWER_MODEL` to override the default model (`openai/gpt-5.3-codex`)

## CodeSimplifier

Install or remove a global `@CodeSimplifier` subagent and `/simplify` command.

```bash
# install
./CodeSimplifier.sh

# uninstall
./CodeSimplifier.sh uninstall
```

Optional environment variables:

- `OPENCODE_CONFIG_DIR` to override the target config path
- `CODESIMPLIFIER_MODEL` to override the default model (`openai/gpt-5.3-codex`)
