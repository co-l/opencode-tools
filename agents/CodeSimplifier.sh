#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="CodeSimplifier"
COMMAND_NAME="simplify"
MODEL="${CODESIMPLIFIER_MODEL:-openai/gpt-5.3-codex}"
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
  CodeSimplifier.sh [install]
  CodeSimplifier.sh uninstall
  CodeSimplifier.sh --uninstall

Description:
  Installs or removes a global OpenCode CodeSimplifier setup:
  - Subagent: @CodeSimplifier
  - Command: /simplify (subtask routed to CodeSimplifier)

Environment variables:
  OPENCODE_CONFIG_DIR    Override ~/.config/opencode target directory
  CODESIMPLIFIER_MODEL   Override model (default: openai/gpt-5.3-codex)
EOF
}

write_agent_file() {
  mkdir -p "$AGENT_DIR"

  cat > "$AGENT_FILE" <<EOF
---
description: Finds overly verbose and complex code, then proposes practical simplifications
mode: subagent
model: ${MODEL}
temperature: 0.1
tools:
  write: false
  edit: false
permission:
  edit: deny
  webfetch: deny
  bash: deny
---
You are a read-only code simplification specialist.

Focus on:
- overly verbose implementations
- unnecessary abstraction or indirection
- deeply nested or branch-heavy logic
- avoidable mutation and side-effect-heavy flows
- repetitive logic that can be composed cleanly

Workflow:
1. Inspect existing project conventions and utilities before suggesting changes.
2. Prioritize simplifications with high readability impact and low behavior risk.
3. Preserve behavior: call out risk when a simplification may alter semantics.
4. Give concrete findings with file paths, severity, and minimal remediation steps.
5. Use concise before/after guidance for each recommendation.

Output format:
- Critical simplifications (high impact, high urgency)
- High-value simplifications
- Optional polish
EOF
}

write_command_files() {
  mkdir -p "$COMMAND_DIR"

  cat > "$COMMAND_FILE" <<'EOF'
---
description: Find code simplification opportunities
agent: CodeSimplifier
subtask: true
---
Run a focused simplification review.

Scope: $ARGUMENTS
If scope is empty, review the current repository for highest-impact simplification opportunities.

Look for:
- over-verbose code
- complex control flow
- unnecessary abstractions
- repetitive logic
- avoidable mutation or side effects

Return:
1) top simplification opportunities (ranked)
2) low-risk remediation steps
3) optional follow-up refactors
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
