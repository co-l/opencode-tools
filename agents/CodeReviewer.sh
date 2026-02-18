#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="CodeReviewer"
COMMAND_NAME="review"
MODEL="${CODEREVIEWER_MODEL:-openai/gpt-5.3-codex}"
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
  CodeReviewer.sh [install]
  CodeReviewer.sh uninstall
  CodeReviewer.sh --uninstall

Description:
  Installs or removes a global OpenCode CodeReviewer setup:
  - Subagent: @CodeReviewer
  - Command: /review (subtask routed to CodeReviewer)

Environment variables:
  OPENCODE_CONFIG_DIR   Override ~/.config/opencode target directory
  CODEREVIEWER_MODEL    Override model (default: openai/gpt-5.3-codex)
EOF
}

write_agent_file() {
  mkdir -p "$AGENT_DIR"

  cat > "$AGENT_FILE" <<EOF
---
description: Reviews uncommitted changes with actionable pre-commit feedback
mode: subagent
model: ${MODEL}
temperature: 0.1
tools:
  write: false
  edit: false
permission:
  edit: deny
  webfetch: deny
  bash:
    "*": deny
    "git status*": allow
    "git diff*": allow
---
You are a read-only code reviewer focused on uncommitted changes.

Scope rules:
- Prioritize staged, unstaged, and untracked changes only.
- Do not run a whole-project audit unless explicitly requested.

Workflow:
1. Gather current change context (git status and diffs).
2. Review correctness, regressions, tests, and maintainability in changed code.
3. Reuse existing project tooling and conventions before proposing new tooling.
4. If tooling is missing for changed-code quality, suggest the minimum necessary addition.

Output format:
- Critical issues (must fix before commit)
- Should fix soon
- Optional improvements

Use concrete file paths and concise remediation steps.
EOF
}

write_command_files() {
  mkdir -p "$COMMAND_DIR"

  cat > "$COMMAND_FILE" <<'EOF'
---
description: Review uncommitted changes with CodeReviewer
agent: CodeReviewer
subtask: true
---
Run a focused review of uncommitted changes only.

Scope hint from user: $ARGUMENTS

Working tree status:
!`git status --short`

Staged diff:
!`git diff --cached --`

Unstaged diff:
!`git diff --`

Review for:
- correctness and regressions
- missing or weak tests
- maintainability and clarity
- convention mismatches

Return:
1) critical issues
2) should-fix before merge
3) optional polish
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
