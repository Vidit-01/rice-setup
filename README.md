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

The script installs KDE Plasma, JetBrains Mono, the listed apt applications,
and the listed snaps if they are missing, then restores the settings and assets.
It saves any existing files it replaces under
`~/.local/state/rice-setup/backups/<timestamp>/`. Log out and back in after it
finishes. It warns and skips app packages that are unavailable from the new
system's configured repositories.

Use `./install.sh --skip-packages` to restore settings and assets only, or
`./install.sh --skip-apps` to install Plasma but skip the app lists. Automatic
package installation supports Ubuntu and Debian.

The app manifests include the user applications found in the apt and snap
inventories. `packages/apt-manual.txt` records all manually marked apt packages;
the installer does not try to restore system packages, kernels, or GPU drivers
from that full inventory. No Flatpak apps were installed when this bundle was
captured. Cisco Packet Tracer was not available as an installable package, so
its launchers are included but its AppImage must be obtained from Cisco.

## Contents

- `config/.config/`: KDE shortcuts, input, window manager, Plasma, application,
  and GTK settings.
- `assets/.local/share/`: active theme, icon set, wallpaper, and panel widgets.
- `packages/`: apt and snap app manifests plus the full apt manual-package list.
- `install.sh`: installer with backups before replacing existing settings.

The saved panel layout uses Agent Panel and Quick Settings. The other installed
widgets are restored into Plasma's widget list but are not added to the panel.
The applet configuration in the layout file preserves the current placement,
popup dimensions, and Agent Panel shortcut.

The snapshot includes `kglobalshortcutsrc` for shortcuts and the KDE input,
KWin, Plasma, notification, Dolphin, Konsole, Spectacle, and System Monitor
settings. It also includes the saved monitor output configuration; review it
on a different display or laptop. It excludes credentials, browser profiles,
email settings, usage history, and other account data. Paths in the Plasma
layout are rewritten for the account running the installer.

## Third-party components

- Ant-Dark Plasma theme, look-and-feel, color scheme, and decoration are bundled
  from the installed setup; see the component metadata in `assets/`.
- YAMIS includes its upstream `LICENSE` and attribution files.
- The Quick Settings widget metadata includes its upstream project URL.
- The wallpaper and Agent Panel widget are from this user's setup.
