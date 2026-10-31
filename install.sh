#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:?HOME is not set}"
BACKUP_ROOT="$HOME_DIR/.local/state/rice-setup/backups/$(date +%Y%m%d-%H%M%S)"
INSTALL_PACKAGES=1
INSTALL_APPS=1

usage() {
    cat <<'EOF'
Usage: ./install.sh [--skip-packages] [--skip-apps]

Install this KDE Plasma 6 setup and listed apps on Ubuntu or Debian. The
default installs missing packages, snaps, and desktop settings. Use
--skip-packages to restore files only, or --skip-apps to install Plasma but
skip the app manifests.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --skip-packages) INSTALL_PACKAGES=0 ;;
        --skip-apps) INSTALL_APPS=0 ;;
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
    case "${ID:-} ${ID_LIKE:-}" in
        ubuntu*|debian*|*debian*) ;;
        *) printf 'Automatic package installation supports Ubuntu and Debian. Use --skip-packages after installing KDE Plasma 6.\n' >&2; exit 1 ;;
    esac

    packages_to_install=()
    for package in kde-plasma-desktop fonts-jetbrains-mono; do
        if ! dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
            packages_to_install+=("$package")
        fi
    done

    if [[ "$INSTALL_APPS" -eq 1 && -f "$SCRIPT_DIR/packages/apt-apps.txt" ]]; then
        while IFS= read -r package; do
            [[ -n "$package" && "$package" != \#* ]] || continue
            if ! dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
                packages_to_install+=("$package")
            fi
        done < "$SCRIPT_DIR/packages/apt-apps.txt"
        if ! command -v snap >/dev/null 2>&1 && [[ -s "$SCRIPT_DIR/packages/snap-apps.tsv" ]]; then
            packages_to_install+=(snapd)
        fi
    fi

    if ((${#packages_to_install[@]})); then
        sudo apt-get update
        available_packages=()
        for package in "${packages_to_install[@]}"; do
            if apt-cache show "$package" 2>/dev/null | grep -Fqx "Package: $package"; then
                available_packages+=("$package")
            else
                printf 'Package not found in configured apt sources; skipped: %s\n' "$package" >&2
            fi
        done
        if ((${#available_packages[@]})); then
            sudo apt-get install -y "${available_packages[@]}"
        fi
    fi

    if [[ "$INSTALL_APPS" -eq 1 && -s "$SCRIPT_DIR/packages/snap-apps.tsv" ]] && command -v snap >/dev/null 2>&1; then
        while read -r snap_name snap_channel snap_flag; do
            [[ -n "${snap_name:-}" && "$snap_name" != \#* ]] || continue
            if snap list "$snap_name" >/dev/null 2>&1; then
                continue
            fi
            snap_args=("--channel=$snap_channel")
            [[ "${snap_flag:-}" == classic ]] && snap_args+=(--classic)
            if ! sudo snap install "$snap_name" "${snap_args[@]}"; then
                printf 'Snap install failed; install manually later: %s\n' "$snap_name" >&2
            fi
        done < "$SCRIPT_DIR/packages/snap-apps.tsv"
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
    if [[ "$name" == "plasma-org.kde.plasma.desktop-appletsrc" || "$name" == "plasmarc" ]]; then
        if [[ -e "$target" ]] && sed "s|@HOME@|$HOME_DIR|g" "$source" | cmp -s - "$target"; then
            return 0
        fi
    elif [[ -e "$target" ]] && cmp -s -- "$source" "$target"; then
        return 0
    fi
    backup_existing "$target"
    mkdir -p "$(dirname -- "$target")"
    if [[ "$name" == "plasma-org.kde.plasma.desktop-appletsrc" || "$name" == "plasmarc" ]]; then
        sed "s|@HOME@|$HOME_DIR|g" "$source" > "$target"
    else
        install -m 0644 "$source" "$target"
    fi
}

install_config_file kdeglobals
install_config_file kwinrc
install_config_file kwinoutputconfig.json
install_config_file kglobalshortcutsrc
install_config_file kcminputrc
install_config_file auroraerc
install_config_file plasma-org.kde.plasma.desktop-appletsrc
install_config_file plasmashellrc
install_config_file plasmarc
install_config_file kactivitymanagerdrc
install_config_file kded5rc
install_config_file krunnerrc
install_config_file powermanagementprofilesrc
install_config_file systemsettingsrc
install_config_file plasmanotifyrc
install_config_file dolphinrc
install_config_file okularpartrc
install_config_file spectaclerc
install_config_file systemmonitorrc
install_config_file konsolerc
install_config_file filetypesrc
install_config_file mimeapps.list
install_config_file gtkrc
install_config_file gtkrc-2.0

install_home_file() {
    local name="$1"
    local source="$SCRIPT_DIR/config/home/$name"
    local target="$HOME_DIR/$name"
    [[ -f "$source" ]] || return 0
    if [[ -e "$target" ]] && cmp -s -- "$source" "$target"; then
        return 0
    fi
    backup_existing "$target"
    install -m 0644 "$source" "$target"
}

install_home_file .bashrc
install_home_file .bash_logout
install_home_file .profile
install_home_file .nvidia-settings-rc

install_config_tree() {
    local name="$1"
    local source="$SCRIPT_DIR/config/.config/$name"
    local target="$HOME_DIR/.config/$name"
    [[ -d "$source" ]] || return 0
    if [[ -d "$target" ]] && diff -qr -- "$source" "$target" >/dev/null; then
        return 0
    fi
    backup_existing "$target"
    mkdir -p "$target"
    cp -a -- "$source/." "$target/"
}

install_config_tree gtk-3.0
install_config_tree gtk-4.0
install_config_tree tiling-assistant
install_config_tree kdedefaults
install_config_tree nvim
install_config_tree yazi
install_config_tree fontconfig
install_config_tree xsettingsd
install_config_tree ghostty

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

install_launcher() {
    local name="$1"
    local source="$SCRIPT_DIR/assets/applications/$name"
    local target="$HOME_DIR/.local/share/applications/$name"
    [[ -f "$source" ]] || return 0
    if [[ -e "$target" ]] && cmp -s -- "$source" "$target"; then
        return 0
    fi
    backup_existing "$target"
    mkdir -p "$(dirname -- "$target")"
    install -m 0644 "$source" "$target"
}

install_launcher brave_brave.desktop
install_launcher gmail.desktop

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

printf '\nRice files installed. Existing files are backed up under:\n%s\n' "$BACKUP_ROOT"
printf 'Log out and back in to apply KDE settings, shortcuts, panel layout, and theme fully.\n'
printf 'Review kwinoutputconfig.json if the new system has different displays or a different monitor layout.\n'
