# Vidit's KDE Plasma setup

This bundle restores the current KDE Plasma 6 look and panel layout on a fresh
Ubuntu or Debian system. It includes the active Ant-Dark theme, YAMIS icons,
JetBrains Mono settings, wallpaper, and the installed Plasma widgets. Agent
Panel and Quick Settings are copied from their editable project packages so
their local customizations are retained.

## Install

From this directory, run:

```bash
./install.sh
```

The script installs `kde-plasma-desktop` and `fonts-jetbrains-mono` with apt if
they are missing, then copies the rice files into your home directory. It saves
any existing files it replaces under
`~/.local/state/rice-setup/backups/<timestamp>/`. Log out and back in after it
finishes.

Use `./install.sh --skip-packages` if Plasma 6 and JetBrains Mono are already
installed or if you use a different distribution.

The saved Plasma panel has launchers for a web browser, Ghostty, and Visual
Studio Code. Install those applications separately if you want all three
launchers to work. The panel layout is based on a single 1920x1080 display;
review it in System Settings if your display arrangement differs.

## Contents

- `config/.config/`: selected KDE and GTK appearance and panel configuration.
- `assets/.local/share/`: active theme, icon set, wallpaper, and panel widgets.
- `install.sh`: installer with backups before replacing existing settings.

The saved panel layout uses Agent Panel and Quick Settings. The other installed
widgets are restored into Plasma's widget list but are not added to the panel.
The applet configuration in the layout file preserves the current placement,
popup dimensions, and Agent Panel shortcut.

The config snapshot intentionally leaves out account credentials, browser
profiles, email settings, monitor output configuration, and other application
data. Paths in the Plasma layout are rewritten for the account running the
installer.

## Third-party components

- Ant-Dark Plasma theme, look-and-feel, color scheme, and decoration are bundled
  from the installed setup; see the component metadata in `assets/`.
- YAMIS includes its upstream `LICENSE` and attribution files.
- The Quick Settings widget metadata includes its upstream project URL.
- The wallpaper and Agent Panel widget are from this user's setup.
