#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Resolve project root
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# -----------------------------
# Sanity checks
# -----------------------------
if ! command -v timeshift >/dev/null 2>&1; then
  echo "Error: timeshift is not installed or not in PATH."
  echo "Install and configure Timeshift before running this script."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Error: this script expects an APT-based system (Ubuntu/Mint)."
  exit 1
fi

# -----------------------------
# 1. Create Timeshift snapshot
# -----------------------------
SNAP_COMMENT="Pre-cleanup snapshot before removing git and project at ${REPO_ROOT}"

echo "Creating Timeshift snapshot..."
sudo timeshift --create --comments "$SNAP_COMMENT" --tags O
echo "Timeshift snapshot created successfully."

# -----------------------------
# 2. Uninstall git
# -----------------------------
if command -v git >/dev/null 2>&1; then
  echo "Uninstalling git..."
  sudo apt-get remove --purge -y git git-man || true
  sudo apt-get autoremove -y || true
  echo "git has been uninstalled (if it was installed)."
else
  echo "git is not installed; skipping uninstall step."
fi

# -----------------------------
# 3. Remove the project root
# -----------------------------
echo "Preparing to remove project root directory: $REPO_ROOT"

# Move out of the repo so we don't sit inside what we delete
cd "$HOME"

if [[ -d "$REPO_ROOT" ]]; then
  rm -rf "$REPO_ROOT"
  echo "Project root directory removed: $REPO_ROOT"
else
  echo "Project root directory not found: $REPO_ROOT (nothing to remove)."
fi

echo "Cleanup complete."
