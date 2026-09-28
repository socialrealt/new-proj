# PW Live for Linux

Single-file launcher that turns https://www.pw.live/study-v2/study into a desktop app.

## Use

1. Download `pw-live.sh`.
2. Make it executable (once): right-click → Properties → "Allow executing as program", or `chmod +x pw-live.sh`.
3. Double-click it (or run `./pw-live.sh`).

First run adds **PW Live** to the app menu and desktop, then opens it. After that, launch it from the menu like any app.

Uninstall: `~/.local/share/pw-live/pw-live.sh --uninstall`

## Requirements

Google Chrome, Chromium, Brave, Edge or Vivaldi (native, Flatpak or Snap). Firefox works as a fallback but opens a normal window, not a standalone one.

The app uses its own browser profile (`~/.config/pw-live/profile`), so your login stays saved and is kept separate from your regular browser.
