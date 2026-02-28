#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="CodeDebugger"
COMMAND_NAME="debug"
MODEL="${CODEDEBUGGER_MODEL:-openai/gpt-5.3-codex}"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}"
AGENT_DIR="${CONFIG_DIR}/agents"
COMMAND_DIR="${CONFIG_DIR}/commands"
LEGACY_COMMAND_DIR="${CONFIG_DIR}/command"
AGENT_FILE="${AGENT_DIR}/${AGENT_NAME}.md"
COMMAND_FILE="${COMMAND_DIR}/${COMMAND_NAME}.md"
LEGACY_COMMAND_FILE="${LEGACY_COMMAND_DIR}/${COMMAND_NAME}.md"

usage() {
  cat <<'EOF'
Usage:
  CodeDebugger.sh [install]
  CodeDebugger.sh uninstall
  CodeDebugger.sh --uninstall

Description:
  Installs or removes a global OpenCode CodeDebugger setup:
  - Subagent: @CodeDebugger
  - Command: /debug (subtask routed to CodeDebugger)

Environment variables:
  OPENCODE_CONFIG_DIR   Override ~/.config/opencode target directory
  CODEDEBUGGER_MODEL    Override model (default: openai/gpt-5.3-codex)
EOF
}

write_agent_file() {
  mkdir -p "$AGENT_DIR"

  cat > "$AGENT_FILE" <<EOF
---
description: |
  Helps debug specific issues that are difficult to resolve. Systematically 
  investigates root causes through hypothesis testing, log analysis, and 
  targeted reproduction. Use when stuck on a bug after multiple failed attempts.
mode: subagent
model: ${MODEL}
temperature: 0.2
tools:
  write: false
  edit: false
permission:
  edit: deny
  webfetch: deny
  bash:
    "*": allow
---
You are a systematic debugging specialist. Your job is to help investigate and 
diagnose issues that have proven difficult to fix.

Debugging principles:
- Form hypotheses before diving into code
- Validate assumptions with targeted tests or log output
- Isolate variables: change one thing at a time
- Work backward from symptoms to root cause
- Consider edge cases and environmental factors

Workflow:
1. Understand the problem: what is expected vs actual behavior?
2. Reproduce the issue: run tests or commands to confirm the bug
3. Gather evidence: read relevant code, check logs, inspect state
4. Form hypotheses: list 2-3 possible root causes ranked by likelihood
5. Test hypotheses: use targeted commands or code inspection to validate
6. Identify root cause: narrow down to the specific faulty logic or state
7. Propose fix: give concrete, minimal changes to resolve the issue

Investigation techniques:
- Add strategic console.log/print statements mentally or suggest them
- Check recent changes (git log, git diff) that may have introduced the bug
- Examine error messages and stack traces carefully
- Look for off-by-one errors, null/undefined, race conditions, state mutations
- Verify assumptions about inputs, outputs, and side effects
- Check for environment differences (versions, config, dependencies)

Output format:
1. Problem summary (1-2 sentences)
2. Reproduction steps and results
3. Investigation findings (what you checked and learned)
4. Root cause analysis (the specific bug and why it occurs)
5. Recommended fix (concrete code changes with file paths and line numbers)
6. Verification steps (how to confirm the fix works)

Be thorough but focused. Do not suggest fixes until you understand the root cause.
EOF
}

write_command_files() {
  mkdir -p "$COMMAND_DIR"

  cat > "$COMMAND_FILE" <<'EOF'
---
description: Debug a specific issue with CodeDebugger
agent: CodeDebugger
subtask: true
---
Help debug a specific issue that has been difficult to resolve.

Problem description: $ARGUMENTS

Your task:
1. Understand and reproduce the issue
2. Systematically investigate root causes
3. Form and test hypotheses
4. Identify the specific bug
5. Propose a minimal, targeted fix

Be methodical. Run tests, check logs, and inspect code before suggesting fixes.
Return your findings with:
- Root cause analysis
- Concrete fix recommendation (file paths + line numbers)
- Verification steps
EOF

  if [[ -d "$LEGACY_COMMAND_DIR" ]]; then
    cp "$COMMAND_FILE" "$LEGACY_COMMAND_FILE"
  fi
}

install() {
  write_agent_file
  write_command_files

  echo "Installed @${AGENT_NAME} and /${COMMAND_NAME}"
  echo "Config directory: ${CONFIG_DIR}"
  echo "Agent file: ${AGENT_FILE}"
  echo "Command file: ${COMMAND_FILE}"
}

cleanup_dir_if_empty() {
  local path="$1"
  if [[ -d "$path" ]] && [[ -z "$(ls -A "$path")" ]]; then
    rmdir "$path"
  fi
}

uninstall() {
  rm -f "$AGENT_FILE" "$COMMAND_FILE" "$LEGACY_COMMAND_FILE"
  cleanup_dir_if_empty "$AGENT_DIR"
  cleanup_dir_if_empty "$COMMAND_DIR"

  echo "Removed @${AGENT_NAME} and /${COMMAND_NAME}"
  echo "Config directory: ${CONFIG_DIR}"
}

main() {
  local action="install"

  if [[ $# -gt 0 ]]; then
    case "$1" in
      install)
        action="install"
        ;;
      uninstall|--uninstall|-u)
        action="uninstall"
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  fi

  if [[ "$action" == "install" ]]; then
    install
  else
    uninstall
  fi
}

main "$@"
