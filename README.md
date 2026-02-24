# opencode-tools

A collection of tools for [opencode](https://github.com/anomalyco/opencode).

## Tools

| Tool | Description |
|------|-------------|
| [timer](./timer/) | Show agent thinking time and token stats for sessions |

## Agents

| Agent utility | Description |
|---------------|-------------|
| [CodeHealth](./agents/CodeHealth.sh) | Installs or removes global `@CodeHealth` and `/health` for code review and codebase health checks |
| [CodeReviewer](./agents/CodeReviewer.sh) | Installs or removes global `@CodeReviewer` and `/review` focused on uncommitted code changes |
| [CodeSimplifier](./agents/CodeSimplifier.sh) | Installs or removes global `@CodeSimplifier` and `/simplify` to find over-verbose or complex code and suggest simplifications |
