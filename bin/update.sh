#!/bin/bash
set -euo pipefail

# --- Configuration ---
# The GitHub workflow file that builds the firmware.
WORKFLOW_FILE="build.yml"
# The artifact name from the workflow. Can be "firmware-no-clique" or "firmware-clique".
ARTIFACT_NAME="firmware-no-clique"
# The temporary directory to download firmware to.
DOWNLOAD_DIR="firmware/latest"
# The name of the volume when the keyboard is in bootloader mode.
# This may vary. Check Disk Utility or /Volumes/ on your system.
KEYBOARD_VOLUME_NAME="ADV360PRO"
# --- End of Configuration ---

# Check for required tools
if ! command -v gh &>/dev/null; then
  echo "Error: The GitHub CLI ('gh') is not installed. Please install it to continue."
  echo "See: https://github.com/cli/cli#installation"
  exit 1
fi

if ! command -v rsync &>/dev/null; then
  echo "Error: 'rsync' is not installed. Please install it to continue."
  exit 1
fi

echo "Looking for the latest successful workflow run for '$WORKFLOW_FILE'..."

# Get the ID of the last successful run
LATEST_RUN_ID=$(gh run list --workflow="$WORKFLOW_FILE" --limit 1 --json databaseId -q '.[0].databaseId // empty')

if [ -z "$LATEST_RUN_ID" ]; then
  echo "Error: No successful workflow runs found."
  exit 1
fi

echo "Found latest successful run with ID: $LATEST_RUN_ID"

# Clean up previous downloads and create fresh directory
rm -rf "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "Downloading artifact '$ARTIFACT_NAME' to '$DOWNLOAD_DIR'..."

# Download the artifact
gh run download "$LATEST_RUN_ID" -n "$ARTIFACT_NAME" -D "$DOWNLOAD_DIR"

echo "Download complete."

# Find the firmware files
LEFT_FIRMWARE=$(find "$DOWNLOAD_DIR" -name "*-left.uf2" | head -n 1)
RIGHT_FIRMWARE=$(find "$DOWNLOAD_DIR" -name "*-right.uf2" | head -n 1)

if [ -z "$LEFT_FIRMWARE" ] || [ -z "$RIGHT_FIRMWARE" ]; then
  echo "Error: Could not find .uf2 firmware files in the downloaded artifact."
  exit 1
fi

echo "Found firmware files:"
echo "  Left: $(basename "$LEFT_FIRMWARE")"
echo "  Right: $(basename "$RIGHT_FIRMWARE")"
echo

# --- Flashing ---
read -p "Which side do you want to flash? (left/right): " SIDE_TO_FLASH

SIDE_TO_FLASH=$(echo "$SIDE_TO_FLASH" | tr '[:upper:]' '[:lower:]')

case "$SIDE_TO_FLASH" in
left)
  FIRMWARE_TO_FLASH=$LEFT_FIRMWARE
  ;;
right)
  FIRMWARE_TO_FLASH=$RIGHT_FIRMWARE
  ;;
*)
  echo "Error: Invalid input. Please enter 'left' or 'right'."
  exit 1
  ;;
esac

KEYBOARD_PATH="/Volumes/$KEYBOARD_VOLUME_NAME"

echo
echo "---"
echo "Ready to flash the '$SIDE_TO_FLASH' side."
echo "1. Put the '$SIDE_TO_FLASH' half of your keyboard into bootloader mode."
echo "2. Wait for the '$KEYBOARD_VOLUME_NAME' volume to mount."
echo "---"
echo
read -p "Press Enter when you are ready to start the sync..."

if [ ! -d "$KEYBOARD_PATH" ]; then
  echo "Error: Keyboard volume not found at '$KEYBOARD_PATH'."
  echo "Please make sure the keyboard is in bootloader mode and mounted correctly."
  exit 1
fi

echo "Keyboard found. Syncing '$(basename "$FIRMWARE_TO_FLASH")' to '$KEYBOARD_PATH'..."

rsync -avh --progress "$FIRMWARE_TO_FLASH" "$KEYBOARD_PATH/"

echo
echo "Sync complete. The keyboard should reboot automatically."
echo "If you need to flash the other side, please run this script again."
