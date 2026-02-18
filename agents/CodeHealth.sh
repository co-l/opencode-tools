#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="CodeHealth"
COMMAND_NAME="health"
MODEL="${CODEHEALTH_MODEL:-openai/gpt-5.3-codex}"
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
  CodeHealth.sh [install]
  CodeHealth.sh uninstall
  CodeHealth.sh --uninstall

Description:
  Installs or removes a global OpenCode CodeHealth setup:
  - Subagent: @CodeHealth
  - Command: /health (subtask routed to CodeHealth)

Environment variables:
  OPENCODE_CONFIG_DIR  Override ~/.config/opencode target directory
  CODEHEALTH_MODEL     Override model (default: openai/gpt-5.3-codex)
EOF
}

write_agent_file() {
  mkdir -p "$AGENT_DIR"

  cat > "$AGENT_FILE" <<EOF
---
description: Reviews code quality, duplication, and maintainability risks with actionable recommendations
mode: subagent
model: ${MODEL}
temperature: 0.1
permission:
  edit: deny
  bash: deny
  webfetch: deny
---
You are a read-only code review and codebase health specialist.

Focus on:
- maintainability
- duplication and dead code
- convention drift
- test gaps
- build and tooling reliability

Workflow:
1. Inspect and reuse existing project tooling before proposing anything new.
2. If required tooling is missing, suggest the minimum necessary tooling.
3. Explain rationale and expected impact.
4. Provide concrete findings with file paths, severity, and minimal remediation steps.
5. Avoid speculative advice.
EOF
}

write_command_files() {
  mkdir -p "$COMMAND_DIR"

  cat > "$COMMAND_FILE" <<'EOF'
---
description: Run a CodeHealth review
agent: CodeHealth
subtask: true
---
Run a focused codebase health review.

Scope: $ARGUMENTS
If scope is empty, review current repo changes and highest-risk modules.

Check for:
- duplication
- dead code
- inconsistent conventions
- risky complexity
- missing tests
- brittle build and tooling

Return:
1) critical issues
2) quick wins
3) deferred recommendations
EOF

  # Compatibility for installations still using ~/.config/opencode/command/
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
