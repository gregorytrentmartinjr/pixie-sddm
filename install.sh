#!/bin/bash

# Pixie SDDM - Universal Smart Installer
# Author: xCaptaiN09

set -e

# All cp/git invocations below use paths relative to the repo, so make
# sure we're standing in the script's own directory regardless of how
# it was launched (e.g. `sudo /path/to/install.sh` from $HOME).
cd "$(dirname "$(readlink -f "$0")")"

THEME_NAME="pixie"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==>${NC} Starting Pixie SDDM Installation..."

# 1. SYSTEM DETECTION
if command -v sddm-greeter-qt6 >/dev/null 2>&1; then
    SYSTEM_QT="6"
    GREETER_CMD="sddm-greeter-qt6"
    TARGET_BRANCH="main"
    echo -e "${BLUE}==>${NC} System detected: ${GREEN}Qt6 (Modern)${NC}"
else
    SYSTEM_QT="5"
    GREETER_CMD="sddm-greeter"
    TARGET_BRANCH="qt5"
    echo -e "${BLUE}==>${NC} System detected: ${YELLOW}Qt5 (Legacy)${NC}"
fi

# 2. AUTO-VERSION SWITCH (Git Only)
if [ -d .git ]; then
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
        echo -e "${YELLOW}==>${NC} System requires ${GREEN}${TARGET_BRANCH}${NC} version. Switching branch..."
        git checkout "$TARGET_BRANCH"
        # Re-run the script from the new branch to ensure we use the right files
        exec ./install.sh
    fi
fi

# 3. NIXOS CHECK
if [ -f /etc/NIXOS ]; then
    echo -e "${RED}Warning:${NC} NixOS detected. Please use the declarative method in your config."
    exit 1
fi

# 4. ROOT CHECK
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} Please run as root (use sudo)."
    exit 1
fi

# 5. INSTALLATION
# Preserve user-dropped per-user wallpapers across re-installs. The repo
# only ships an empty assets/backgrounds/ (with a .gitkeep), so a naive
# rm -rf wipes any <username>.jpg files the user added under there.
BG_BACKUP=""
if [ -d "${THEME_DIR}" ]; then
    if [ -d "${THEME_DIR}/assets/backgrounds" ]; then
        BG_BACKUP=$(mktemp -d)
        cp -a "${THEME_DIR}/assets/backgrounds/." "${BG_BACKUP}/" 2>/dev/null || true
    fi
    echo -e "${BLUE}==>${NC} Cleaning old version..."
    rm -rf "${THEME_DIR}"
fi

echo -e "${BLUE}==>${NC} Installing Pixie (Qt${SYSTEM_QT}) to ${THEME_DIR}..."
mkdir -p "${THEME_DIR}"
cp -r assets components Main.qml metadata.desktop theme.conf LICENSE "${THEME_DIR}/"
chmod -R 755 "${THEME_DIR}"

if [ -n "${BG_BACKUP}" ] && [ -d "${BG_BACKUP}" ]; then
    echo -e "${BLUE}==>${NC} Restoring per-user wallpapers..."
    mkdir -p "${THEME_DIR}/assets/backgrounds"
    cp -a "${BG_BACKUP}/." "${THEME_DIR}/assets/backgrounds/" 2>/dev/null || true
    rm -rf "${BG_BACKUP}"
fi

echo -e "${GREEN}Done!${NC} Pixie SDDM is now installed."

# 6. STATE DIRECTORY (for runtime config synced from user shells)
# /var/lib/pixie-sddm/state.conf carries shell-style key=value lines (e.g.
# clockFormat=h:mm ap) written by the user's quickshell BarConfig and read
# by the SDDM theme. Sticky-bit world-writable mirrors /tmp's policy: any
# user can drop a file, but only the owner can overwrite or delete it.
echo -e "${BLUE}==>${NC} Creating state directory /var/lib/pixie-sddm..."
install -d -m 1777 /var/lib/pixie-sddm

# Helper that upserts a key=value line into state.conf. User shells (e.g.
# quickshell's BarConfig) call this to push individual keys without
# clobbering the others. Installed system-wide so it's on $PATH for any user.
echo -e "${BLUE}==>${NC} Installing state-update helper /usr/local/bin/pixie-sddm-set-state..."
cat > /usr/local/bin/pixie-sddm-set-state <<'HELPER_EOF'
#!/bin/sh
# pixie-sddm-set-state KEY VALUE
# Upserts a single key=value line in /var/lib/pixie-sddm/state.conf so the
# Pixie SDDM theme can pick it up at the next greeter start.

set -eu

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <key> <value>" >&2
    exit 2
fi

KEY=$1
VAL=$2
STATE=/var/lib/pixie-sddm/state.conf
DIR=$(dirname "$STATE")

# Silently no-op when Pixie SDDM isn't installed.
[ -d "$DIR" ] || exit 0

# Restrict KEY to identifier chars so it's safe to use as a literal grep pattern.
case "$KEY" in
    *[!A-Za-z0-9_]*) echo "invalid key: $KEY" >&2; exit 2 ;;
esac

TMP=$(mktemp 2>/dev/null) || exit 0
{
    [ -f "$STATE" ] && grep -v "^${KEY}=" "$STATE" || true
    printf '%s=%s\n' "$KEY" "$VAL"
} > "$TMP"

# Truncate-overwrite when we can already write the existing file (preserves
# the inode and avoids the sticky-bit unlink restriction on /var/lib/pixie-sddm).
# Otherwise rename in, falling back to a copy if rename is blocked.
if [ -f "$STATE" ] && [ -w "$STATE" ]; then
    cat "$TMP" > "$STATE"
    rm -f "$TMP"
else
    mv "$TMP" "$STATE" 2>/dev/null || { cat "$TMP" > "$STATE"; rm -f "$TMP"; }
fi
chmod 666 "$STATE" 2>/dev/null || true
HELPER_EOF
chmod 755 /usr/local/bin/pixie-sddm-set-state

# Qt6 disables file:// reads via XMLHttpRequest by default. The Clock component
# uses XHR to load /var/lib/pixie-sddm/state.conf, so the greeter needs the
# QML_XHR_ALLOW_FILE_READ=1 env var. A systemd drop-in is the least intrusive
# way to set it for the running greeter without touching the unit file itself.
SDDM_OVERRIDE_DIR=/etc/systemd/system/sddm.service.d
echo -e "${BLUE}==>${NC} Installing systemd drop-in for QML file-read permission..."
mkdir -p "$SDDM_OVERRIDE_DIR"
cat > "$SDDM_OVERRIDE_DIR/pixie-qml-xhr.conf" <<'EOF'
[Service]
Environment="QML_XHR_ALLOW_FILE_READ=1"
EOF
systemctl daemon-reload 2>/dev/null || true

# Bootstrap: seed state.conf from the calling user's quickshell config so the
# theme reflects the current setting on first boot, before quickshell runs.
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER_CONFIG="${USER_HOME}/.config/illogical-impulse/config.json"
    if [ -r "$USER_CONFIG" ]; then
        if command -v jq >/dev/null 2>&1; then
            FMT=$(jq -r '.options.time.format // empty' "$USER_CONFIG" 2>/dev/null)
        else
            # Portable fallback: extract the first "format": "<value>" inside the time block.
            FMT=$(awk '/"time"[[:space:]]*:/,/}/' "$USER_CONFIG" \
                  | sed -nE 's/.*"format"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
                  | head -1)
        fi
        if [ -n "$FMT" ]; then
            pixie-sddm-set-state clockFormat "$FMT" 2>/dev/null || true
            echo -e "${BLUE}==>${NC} Seeded clockFormat=${GREEN}${FMT}${NC} from quickshell config."
        fi
        DFMT=$(jq -r '.options.time.dateFormat // empty' "$USER_CONFIG" 2>/dev/null \
               || awk '/"time"[[:space:]]*:/,/}/' "$USER_CONFIG" \
                  | sed -nE 's/.*"dateFormat"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
                  | head -1)
        if [ -n "$DFMT" ]; then
            pixie-sddm-set-state dateFormat "$DFMT" 2>/dev/null || true
            echo -e "${BLUE}==>${NC} Seeded dateFormat=${GREEN}${DFMT}${NC} from quickshell config."
        fi
    fi
fi

# 7. CONFIGURATION
echo -e ""
read -p "Apply Pixie as your active theme now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p /etc/sddm.conf.d
    echo -e "[Theme]\nCurrent=${THEME_NAME}" | tee /etc/sddm.conf.d/theme.conf > /dev/null
    echo -e "${GREEN}Theme applied successfully!${NC}"
else
    echo -e "To apply manually, set ${GREEN}Current=${THEME_NAME}${NC} in your SDDM config."
fi

echo -e ""
echo -e "Test with: ${BLUE}QML_XHR_ALLOW_FILE_READ=1 ${GREETER_CMD} --test-mode --theme ${THEME_DIR}${NC}"
