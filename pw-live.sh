#!/usr/bin/env bash
# PW Live desktop app for Linux.
#
# First run: installs a launcher (app menu + desktop icon) and opens the app.
# Later runs: just opens the app.
#
#   ./pw-live.sh              install (if needed) and launch
#   ./pw-live.sh --uninstall  remove launcher, icon and app profile
#
# The site runs in a Chromium-based browser's standalone "app" window
# (no tabs/address bar) with its own profile, so login persists and stays
# separate from your normal browser. Chromium-family browsers are preferred
# because they ship Widevine, which some video players require.

set -euo pipefail

APP_ID="pw-live"
APP_NAME="PW Live"
APP_URL="https://www.pw.live/study-v2/study"
APP_HOST="www.pw.live"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
INSTALL_DIR="$DATA_HOME/$APP_ID"
PROFILE_DIR="$CONFIG_HOME/$APP_ID/profile"
BIN_PATH="$INSTALL_DIR/$APP_ID.sh"
ICON_PATH="$DATA_HOME/icons/hicolor/scalable/apps/$APP_ID.svg"
ICON_PNG="$DATA_HOME/icons/hicolor/256x256/apps/$APP_ID.png"
DESKTOP_FILE="$DATA_HOME/applications/$APP_ID.desktop"

notify() {
    echo "$*" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$APP_NAME" "$*" 2>/dev/null || true
    elif command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$APP_NAME" --text="$*" 2>/dev/null || true
    fi
}

die() {
    echo "Error: $*" >&2
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$APP_NAME" --text="$*" 2>/dev/null || true
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "$APP_NAME" "$*" 2>/dev/null || true
    fi
    exit 1
}

# Prints "<kind> <command...>" for the first usable browser.
find_browser() {
    local b
    for b in google-chrome-stable google-chrome chromium chromium-browser \
             brave-browser brave microsoft-edge-stable microsoft-edge vivaldi-stable vivaldi; do
        if command -v "$b" >/dev/null 2>&1; then
            echo "chromium $(command -v "$b")"
            return 0
        fi
    done
    if command -v flatpak >/dev/null 2>&1; then
        for b in com.google.Chrome org.chromium.Chromium com.brave.Browser com.microsoft.Edge; do
            if flatpak info "$b" >/dev/null 2>&1; then
                echo "chromium flatpak run $b"
                return 0
            fi
        done
    fi
    if command -v snap >/dev/null 2>&1 && snap list chromium >/dev/null 2>&1; then
        echo "chromium /snap/bin/chromium"
        return 0
    fi
    if command -v firefox >/dev/null 2>&1; then
        echo "firefox $(command -v firefox)"
        return 0
    fi
    return 1
}

write_icon() {
    mkdir -p "$(dirname "$ICON_PATH")"
    cat >"$ICON_PATH" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="56" fill="#5a4bda"/>
  <text x="128" y="162" font-family="DejaVu Sans, Arial, sans-serif" font-size="112"
        font-weight="700" fill="#ffffff" text-anchor="middle">PW</text>
</svg>
SVG
    # Try to use the site's real icon; keep the SVG if that fails.
    if command -v curl >/dev/null 2>&1; then
        local tmp
        tmp="$(mktemp)"
        if curl -fsL --max-time 10 -o "$tmp" "https://$APP_HOST/apple-touch-icon.png" \
           && file -b --mime-type "$tmp" 2>/dev/null | grep -q '^image/png'; then
            mkdir -p "$(dirname "$ICON_PNG")"
            mv "$tmp" "$ICON_PNG"
            rm -f "$ICON_PATH"
        else
            rm -f "$tmp"
        fi
    fi
}

install_app() {
    mkdir -p "$INSTALL_DIR" "$PROFILE_DIR" "$(dirname "$DESKTOP_FILE")"

    # Copy this script to a stable location so the launcher survives
    # the original file being moved or deleted.
    local self
    self="$(readlink -f "${BASH_SOURCE[0]}")"
    if [ "$self" != "$BIN_PATH" ]; then
        cp "$self" "$BIN_PATH"
        chmod +x "$BIN_PATH"
    fi

    write_icon

    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Physics Wallah study portal
Exec="$BIN_PATH"
Icon=$APP_ID
Terminal=false
Categories=Education;Network;
StartupNotify=true
StartupWMClass=$APP_ID
EOF
    chmod +x "$DESKTOP_FILE"

    # Desktop shortcut, if the user has a desktop folder.
    local desktop_dir
    desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
    if [ -d "$desktop_dir" ]; then
        cp "$DESKTOP_FILE" "$desktop_dir/$APP_ID.desktop"
        chmod +x "$desktop_dir/$APP_ID.desktop"
        # GNOME requires the launcher to be marked trusted.
        gio set "$desktop_dir/$APP_ID.desktop" metadata::trusted true 2>/dev/null || true
    fi

    command -v update-desktop-database >/dev/null 2>&1 \
        && update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 \
        && gtk-update-icon-cache -q -t "$DATA_HOME/icons/hicolor" 2>/dev/null || true

    notify "Installed. $APP_NAME is now in your app menu."
}

uninstall_app() {
    local desktop_dir
    desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
    rm -f "$DESKTOP_FILE" "$desktop_dir/$APP_ID.desktop" "$ICON_PATH" "$ICON_PNG"
    rm -rf "$INSTALL_DIR" "$CONFIG_HOME/$APP_ID"
    command -v update-desktop-database >/dev/null 2>&1 \
        && update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true
    echo "$APP_NAME uninstalled."
}

launch_app() {
    local found kind
    found="$(find_browser)" || die "No supported browser found. Install Google Chrome or Chromium, then run this again."
    kind="${found%% *}"
    # shellcheck disable=SC2206
    local cmd=(${found#* })

    case "$kind" in
        chromium)
            exec "${cmd[@]}" \
                --app="$APP_URL" \
                --user-data-dir="$PROFILE_DIR" \
                --class="$APP_ID" \
                --no-first-run \
                --no-default-browser-check \
                --window-size=1280,800 \
                >/dev/null 2>&1
            ;;
        firefox)
            mkdir -p "$PROFILE_DIR-firefox"
            exec "${cmd[@]}" --no-remote --profile "$PROFILE_DIR-firefox" \
                --class "$APP_ID" --new-window "$APP_URL" >/dev/null 2>&1
            ;;
    esac
}

case "${1:-}" in
    --uninstall) uninstall_app; exit 0 ;;
    --install)   install_app; exit 0 ;;
    -h|--help)   sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ ! -f "$DESKTOP_FILE" ] || [ ! -x "$BIN_PATH" ]; then
    install_app
fi
launch_app
