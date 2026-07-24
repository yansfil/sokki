#!/bin/bash
# Installs the latest Sokki release into /Applications and launches it.
# One-liner (no Xcode, no gh, no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/modakbul-gongbang/sokki/main/scripts/install.sh | bash
set -euo pipefail

REPO="modakbul-gongbang/sokki"
APP="/Applications/Sokki.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Sokki only runs on macOS." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Sokki requires Apple Silicon (arm64). This Mac is $(uname -m)." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
MOUNT=""
cleanup() {
  if [[ -n "$MOUNT" ]]; then hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "==> Finding the latest Sokki release"
DMG_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.dmg"' \
  | grep -o 'https://[^"]*' \
  | head -1)"
if [[ -z "$DMG_URL" ]]; then
  echo "Could not find a DMG in the latest release of ${REPO}." >&2
  echo "Check https://github.com/${REPO}/releases manually." >&2
  exit 1
fi

echo "==> Downloading $(basename "$DMG_URL")"
curl -fL --progress-bar -o "$TMP_DIR/Sokki.dmg" "$DMG_URL"

echo "==> Installing to $APP"
MOUNT="$(hdiutil attach "$TMP_DIR/Sokki.dmg" -nobrowse -readonly \
  | awk -F'\t' '/\/Volumes\//{print $NF}' | head -1)"
if [[ -z "$MOUNT" || ! -d "$MOUNT/Sokki.app" ]]; then
  echo "Failed to mount the DMG or Sokki.app is missing from it." >&2
  exit 1
fi
osascript -e 'quit app "Sokki"' >/dev/null 2>&1 || true
sleep 1
rm -rf "$APP"
ditto "$MOUNT/Sokki.app" "$APP"
hdiutil detach "$MOUNT" >/dev/null
MOUNT=""

# curl downloads carry no quarantine flag, but clear it defensively in case
# this DMG was fetched by a browser first (releases are ad-hoc signed, not
# notarized, so a quarantined copy would be blocked by Gatekeeper).
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "==> Launching Sokki"
open "$APP"

cat <<'EOF'

Sokki is installed. Look for the microphone icon in the menu bar
(there is no Dock icon). The welcome window will ask you to:

  1. Allow Microphone and Speech Recognition when prompted.
  2. (Recommended) Enable Sokki under System Settings
     -> Privacy & Security -> Accessibility, so dictated text is
     pasted at your cursor instead of only copied to the clipboard.

Then click into any text field, press Ctrl+Option+Space, speak,
and press Ctrl+Option+Space again.
EOF
