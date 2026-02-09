#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="/usr/local/bin/timer"

echo "Installing timer -> $TARGET"
sudo ln -sf "$SCRIPT_DIR/timer" "$TARGET"
echo "Done! You can now use 'timer' or '!timer' in opencode."
