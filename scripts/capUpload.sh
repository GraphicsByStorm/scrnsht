#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (directory above scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load config
CONFIG_FILE="$REPO_ROOT/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  echo "Copy config.env.example to config.env and edit it."
  exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Ensure required commands exist
# SCREENSHOT_CMD might contain args (e.g. "gnome-screenshot -f"), so split the base command
BASE_SCREENSHOT_CMD="${SCREENSHOT_CMD%% *}"

for cmd in mount umount "$BASE_SCREENSHOT_CMD"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing command: $cmd"
    echo "Install it and try again."
    exit 1
  fi
done

# Create directories
mkdir -p "$LOCAL_SCREENSHOT_DIR" "$MOUNT_POINT"

TIMESTAMP="$(date +%F-%H%M%S)"
LOCAL_FILE="$LOCAL_SCREENSHOT_DIR/${SCREENSHOT_PREFIX}-${TIMESTAMP}.png"

cleanup() {
  echo "Cleaning up: attempting to unmount $MOUNT_POINT"
  sudo umount "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

echo "Taking screenshot to: $LOCAL_FILE"
# $SCREENSHOT_CMD already includes its own flags, just append filename
# shellcheck disable=SC2086
$SCREENSHOT_CMD "$LOCAL_FILE"

if [[ ! -f "$LOCAL_FILE" ]]; then
  echo "Screenshot file was not created: $LOCAL_FILE"
  exit 1
fi

if [[ ! -f "$SMB_CREDENTIALS_FILE" ]]; then
  echo "SMB credentials file not found: $SMB_CREDENTIALS_FILE"
  echo "Expected a file like:"
  echo "  username=Guest"
  echo "  password="
  echo "  domain=WORKGROUP"
  exit 1
fi

echo "Mounting SMB share //${WIN_IP}/${SHARE_NAME} to $MOUNT_POINT using creds: $SMB_CREDENTIALS_FILE"

sudo mount -t cifs "//${WIN_IP}/${SHARE_NAME}" "$MOUNT_POINT" \
  -o "credentials=${SMB_CREDENTIALS_FILE},vers=3.0,uid=$UID,gid=$(id -g)"

echo "Copying screenshot to SMB share..."
cp "$LOCAL_FILE" "$MOUNT_POINT/"

echo "Syncing writes..."
sync

echo "Unmounting SMB share..."
sudo umount "$MOUNT_POINT" || true

echo "Upload complete. Shutting down..."
$SHUTDOWN_CMD