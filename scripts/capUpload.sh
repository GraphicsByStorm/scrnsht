#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$REPO_ROOT/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    echo "Copy config.env.example to config.env and edit it."
    exit 1
fi

source "$CONFIG_FILE"

for cmd in mount umount $SCREENSHOT_CMD; do
    base_cmd="${cmd%% *}"
    if ! command -v "$base_cmd" >/dev/null 2>&1; then
        echo "Missing command: $base_cmd"
        echo "Install it and try again."
        exit 1
    fi
done

if ! command -v cif-utils >/dev/null 2>&1 && ! grep -q "cifs" <(lsmod || true); then
    echo "Warning: cifs-utils may not be installed. On Debian/Ubuntu/Mint:"
    echo " sudo apt install cifs-utils"
fi

mkdir -p "$LOCAL_SCREENSHOT_DIR" "$MOUNT_POINT"

TIMESTAMP="$(date +%F-%H%M%S)"
LOCAL_FILE="$LOCAL_SCREENSHOT_DIR/${SCREENSHOT_PREFIX}-${TIMESTAMP}.png"

cleanup() {
    echo "Cleaning up: attempting to umount $MOUNT_POINT"
    sudo umount "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

echo "Taking screenshot to: $LOCAL_FILE"
$SCREENSHOT_CMD "$LOCAL_FILE"

if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "Screenshot file was not created: $LOCAL_FILE"
    exit 1
fi

echo "Mounting SMB share //${WIN_IP}/${SHARE_NAME} to $MOUNT_POINT"
if [[ ! -f "$SMB_CREDENTIALS_FILE" ]]; then
    echo "SMB credentials file not found: $SMB_CREDENTIALS_FILE"
    echo "Create it, e.g.:"
    echo " username=Guest"
    echo " password= "
    echo " domain=WORKGROUP"
    exit 1
fi

sudo mount -t cifs "//${WIN_IP}/${SHARE_NAME}" "$MOUNT_POINT" \
    -o "credentials=${SMB_CREDENTIALS_FILE}, vers=3.0,uid=$UID,gid=$(id -g),sec=ntlmssp"

echo "Copying screenshot to SMB share..."
cp "$LOCAL_FILE" "$MOUNT_POINT/"

echo "Syncing writes..."
sync

echo "Unmounting SMB share..."
sudo umount "$MOUNT_POINT" || true

echo "Upload complete. Shutting down..."
$SHUTDOWN_CMD