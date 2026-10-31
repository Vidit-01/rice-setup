#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:?HOME is not set}"
BACKUP_ROOT="$HOME_DIR/.local/state/rice-setup/backups/$(date +%Y%m%d-%H%M%S)"
INSTALL_PACKAGES=1

usage() {
    cat <<'EOF'
Usage: ./install.sh [--skip-packages]

Install this KDE Plasma 6 setup on Ubuntu or Debian. The default installs the
Plasma desktop and JetBrains Mono if they are missing, then restores the rice.
Use --skip-packages to restore the files only.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --skip-packages) INSTALL_PACKAGES=0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ "$INSTALL_PACKAGES" -eq 1 ]]; then
    if [[ ! -r /etc/os-release ]]; then
        printf 'Cannot identify this system. Install KDE Plasma 6 and JetBrains Mono first.\n' >&2
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
        ubuntu:*|debian:*|*:* debian*) ;;
        *) printf 'Automatic package installation supports Ubuntu and Debian. Use --skip-packages after installing KDE Plasma 6.\n' >&2; exit 1 ;;
    esac

    missing=()
    dpkg-query -W -f='${Status}' kde-plasma-desktop 2>/dev/null | grep -q 'install ok installed' || missing+=(kde-plasma-desktop)
    dpkg-query -W -f='${Status}' fonts-jetbrains-mono 2>/dev/null | grep -q 'install ok installed' || missing+=(fonts-jetbrains-mono)
    if ((${#missing[@]})); then
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    fi
fi

if [[ ! -d "$SCRIPT_DIR/assets/.local/share" || ! -d "$SCRIPT_DIR/config/.config" ]]; then
    printf 'This script must stay beside the config/ and assets/ directories.\n' >&2
    exit 1
fi

mkdir -p "$BACKUP_ROOT"

backup_existing() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    local relative="${target#"$HOME_DIR"/}"
    local backup="$BACKUP_ROOT/$relative"
    mkdir -p "$(dirname -- "$backup")"
    cp -a -- "$target" "$backup"
}

install_config_file() {
    local name="$1"
    local source="$SCRIPT_DIR/config/.config/$name"
    local target="$HOME_DIR/.config/$name"
    [[ -f "$source" ]] || return 0
    if [[ -e "$target" ]] && cmp -s -- "$source" "$target"; then
        return 0
    fi
    backup_existing "$target"
    mkdir -p "$(dirname -- "$target")"
    if [[ "$name" == "plasma-org.kde.plasma.desktop-appletsrc" ]]; then
        sed "s|@HOME@|$HOME_DIR|g" "$source" > "$target"
    else
        install -m 0644 "$source" "$target"
    fi
}

install_config_file kdeglobals
install_config_file kwinrc
install_config_file auroraerc
install_config_file plasma-org.kde.plasma.desktop-appletsrc
install_config_file gtkrc
install_config_file gtkrc-2.0

for name in gtk-3.0 gtk-4.0; do
    source="$SCRIPT_DIR/config/.config/$name"
    target="$HOME_DIR/.config/$name"
    [[ -d "$source" ]] || continue
    if [[ -d "$target" ]] && diff -qr -- "$source" "$target" >/dev/null; then
        continue
    fi
    backup_existing "$target"
    mkdir -p "$target"
    cp -a -- "$source/." "$target/"
done

install_asset_tree() {
    local relative="$1"
    local source="$SCRIPT_DIR/assets/$relative"
    local target="$HOME_DIR/$relative"
    [[ -d "$source" ]] || return 0
    if [[ -d "$target" ]] && diff -qr -- "$source" "$target" >/dev/null; then
        return 0
    fi
    backup_existing "$target"
    mkdir -p "$target"
    cp -a -- "$source/." "$target/"
}

install_asset_tree .local/share/aurorae/themes/Ant-Dark
install_asset_tree .local/share/color-schemes
install_asset_tree .local/share/icons/YAMIS
install_asset_tree .local/share/plasma/desktoptheme/Ant-Dark
install_asset_tree .local/share/plasma/look-and-feel/Ant-Dark
install_asset_tree .local/share/plasma/plasmoids/AndromedaLauncher
install_asset_tree .local/share/plasma/plasmoids/KdeControlStation
install_asset_tree .local/share/plasma/plasmoids/com.arvin.dynamicisland
install_asset_tree .local/share/plasma/plasmoids/com.vidit.agentpanel
install_asset_tree .local/share/plasma/plasmoids/com.github.luciotorelli.quicksettings
install_asset_tree .local/share/plasma/plasmoids/org.kde.plasma.macosdock
install_asset_tree .local/share/rice-setup/wallpapers

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

printf '\nRice files installed. Existing files are backed up under:\n%s\n' "$BACKUP_ROOT"
printf 'Log out and back in to apply the Plasma layout and theme fully.\n'
printf 'The panel launchers expect a browser, Ghostty, and Visual Studio Code to be installed.\n'
