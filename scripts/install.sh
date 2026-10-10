#!/usr/bin/env bash
# Skeldri Universal One-Line Installer for Linux & Omarchy
# Usage: curl -fsSL https://onembyte.github.io/Skeldri/install.sh | bash
set -e

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

REPO="onembyte/Skeldri"
GITHUB_RAW="https://raw.githubusercontent.com/${REPO}/main"
GITHUB_RELEASES="https://github.com/${REPO}/releases"

echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${CYAN}  SKELDRI (DRAWPAD) — LINUX & OMARCHY INSTALLER${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"

# 1. Detect OS & Architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH_RAW="$(uname -m)"

case "$ARCH_RAW" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        ARCH="$ARCH_RAW"
        ;;
esac

echo -e "  Detected Platform: ${BOLD}${OS} (${ARCH})${RESET}"

if [ "$OS" != "linux" ]; then
    echo -e "${YELLOW}Notice: This script is optimized for Linux / Omarchy. For macOS, open DrawPad.xcodeproj in Xcode.${RESET}"
fi

# 2. Determine installation directories
if [ -d "$HOME/.local/bin" ] || [ "$OS" = "linux" ]; then
    INSTALL_DIR="$HOME/.local/bin"
elif [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
fi
mkdir -p "$INSTALL_DIR"

TMP_DIR="$(mktemp -d /tmp/skeldri-install.XXXXXX)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# 3. Download prebuilt binary or compile from source
INSTALLED=0

echo -e "  Fetching Skeldri..."
RELEASE_URL="${GITHUB_RELEASES}/latest/download/skeldri-${OS}-${ARCH}.tar.gz"

if curl -fsSLI "$RELEASE_URL" >/dev/null 2>&1; then
    echo -e "  Downloading prebuilt release from GitHub..."
    if curl -fsSL "$RELEASE_URL" -o "$TMP_DIR/skeldri.tar.gz"; then
        tar -xzf "$TMP_DIR/skeldri.tar.gz" -C "$TMP_DIR"
        BIN_PATH="$(find "$TMP_DIR" -type f -name "skeldri" | head -n 1)"
        if [ -n "$BIN_PATH" ]; then
            install -m755 "$BIN_PATH" "$INSTALL_DIR/skeldri"
            INSTALLED=1
        fi
    fi
fi

# Fallback: build from source if prebuilt release is not available
if [ "$INSTALLED" -eq 0 ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd || echo "")"
    LOCAL_CARGO="$SCRIPT_DIR/../linux/Cargo.toml"

    if [ -f "$LOCAL_CARGO" ]; then
        echo -e "  Compiling from local source..."
        (cd "$SCRIPT_DIR/../linux" && cargo build --release --bin skeldri)
        install -m755 "$SCRIPT_DIR/../linux/target/release/skeldri" "$INSTALL_DIR/skeldri"
        INSTALLED=1
    elif command -v cargo >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
        echo -e "  Cloning and compiling latest source via cargo..."
        git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_DIR/skeldri-src"
        (cd "$TMP_DIR/skeldri-src/linux" && cargo build --release --bin skeldri)
        install -m755 "$TMP_DIR/skeldri-src/linux/target/release/skeldri" "$INSTALL_DIR/skeldri"
        INSTALLED=1
    else
        echo -e "${RED}Error: Precompiled binary not found and Rust/Cargo is not installed.${RESET}"
        echo -e "Please install Rust (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh) or install via PKGBUILD."
        exit 1
    fi
fi

echo -e "  ${GREEN}✔ Installed binary:${RESET} ${INSTALL_DIR}/skeldri"

# 4. Install Desktop File
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

if [ -f "$SCRIPT_DIR/../skeldri.desktop" ]; then
    cp "$SCRIPT_DIR/../skeldri.desktop" "$DESKTOP_DIR/skeldri.desktop"
elif [ -f "$TMP_DIR/skeldri.desktop" ]; then
    cp "$TMP_DIR/skeldri.desktop" "$DESKTOP_DIR/skeldri.desktop"
else
    cat << 'EOF' > "$DESKTOP_DIR/skeldri.desktop"
[Desktop Entry]
Name=Skeldri DrawPad
Comment=iPad wireless screen mirroring and live annotation overlay
Exec=skeldri
Icon=input-tablet
Terminal=false
Type=Application
Categories=Utility;Graphics;
Keywords=ipad;mirror;drawing;tablet;annotation;drawpad;
EOF
fi
echo -e "  ${GREEN}✔ Installed desktop entry:${RESET} ${DESKTOP_DIR}/skeldri.desktop"

# 5. Install Systemd User Service
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

if [ -f "$SCRIPT_DIR/../skeldri.service" ]; then
    cp "$SCRIPT_DIR/../skeldri.service" "$SYSTEMD_DIR/skeldri.service"
elif [ -f "$TMP_DIR/skeldri.service" ]; then
    cp "$TMP_DIR/skeldri.service" "$SYSTEMD_DIR/skeldri.service"
else
    cat << EOF > "$SYSTEMD_DIR/skeldri.service"
[Unit]
Description=Skeldri DrawPad - iPad Screen Mirroring & Annotation Daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/skeldri
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF
fi

systemctl --user daemon-reload 2>/dev/null || true
echo -e "  ${GREEN}✔ Installed systemd service:${RESET} ${SYSTEMD_DIR}/skeldri.service"

# 6. Install Omarchy QuickShell Bar Plugin (if Omarchy is present)
OMARCHY_PLUGIN_DIR="$HOME/.config/omarchy/plugins/skeldri"
if [ -d "$HOME/.config/omarchy" ] || [ -d "/usr/share/omarchy" ]; then
    mkdir -p "$OMARCHY_PLUGIN_DIR"
    if [ -f "$SCRIPT_DIR/../plugins/skeldri/manifest.json" ]; then
        cp "$SCRIPT_DIR/../plugins/skeldri/manifest.json" "$OMARCHY_PLUGIN_DIR/manifest.json"
        cp "$SCRIPT_DIR/../plugins/skeldri/Panel.qml" "$OMARCHY_PLUGIN_DIR/Panel.qml"
    elif [ -f "$TMP_DIR/plugins/skeldri/manifest.json" ]; then
        cp "$TMP_DIR/plugins/skeldri/manifest.json" "$OMARCHY_PLUGIN_DIR/manifest.json"
        cp "$TMP_DIR/plugins/skeldri/Panel.qml" "$OMARCHY_PLUGIN_DIR/Panel.qml"
    else
        curl -fsSL "${GITHUB_RAW}/plugins/skeldri/manifest.json" -o "$OMARCHY_PLUGIN_DIR/manifest.json" 2>/dev/null || true
        curl -fsSL "${GITHUB_RAW}/plugins/skeldri/Panel.qml" -o "$OMARCHY_PLUGIN_DIR/Panel.qml" 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✔ Installed Omarchy bar plugin:${RESET} ${OMARCHY_PLUGIN_DIR}/"
fi

# 7. Check PATH
case ":$PATH:" in
    *:"$INSTALL_DIR":*)
        ;;
    *)
        echo -e "\n  ${YELLOW}Notice: ${INSTALL_DIR} is not in your PATH.${RESET}"
        echo -e "  Add it by appending this to your ~/.bashrc or ~/.zshrc:"
        echo -e "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
        ;;
esac

echo -e "\n${BOLD}${GREEN}✔ Installation successful!${RESET}"
echo -e "\nTo start Skeldri in the background:"
echo -e "  ${CYAN}systemctl --user enable --now skeldri.service${RESET}"
echo -e "\nOr run interactively:"
echo -e "  ${CYAN}skeldri${RESET}\n"
