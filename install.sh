#!/usr/bin/env sh
# install.sh — One-command installer for openpreset router suite.
# Usage: curl -fsSL https://raw.githubusercontent.com/zaidsubhani135/claude-router/main/install.sh | sh
set -eu

VERSION="2.0.0"
REPO="zaidsubhani135/claude-router"
TARBALL_NAME="openpreset-v${VERSION}.tar.gz"
TARBALL_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${TARBALL_NAME}"

printf '%s\n' "========================================================"
printf '%s\n' "  🚀 openpreset v${VERSION} Installer"
printf '%s\n' "========================================================"

# Determine target directories (User vs System)
if [ "$(id -u)" -eq 0 ]; then
    BIN_DIR="/usr/local/bin"
    SHARE_DIR="/usr/local/share/openpreset"
    printf '%s\n' "📍 Installation target: System-wide (${BIN_DIR})"
else
    BIN_DIR="${HOME}/.local/bin"
    SHARE_DIR="${HOME}/.local/share/openpreset"
    printf '%s\n' "📍 Installation target: User directory (${BIN_DIR})"
fi

# Dependency check
printf '%s\n' "🔍 Checking dependencies..."
for dep in curl jq; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        printf '%s\n' "❌ Missing required dependency: $dep. Please install $dep and re-run." >&2
        exit 1
    fi
done
if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "  ✓ fzf found (enhanced UI enabled)"
else
    printf '%s\n' "  ⚠️  fzf not found (will fallback to text menus). Install fzf for optimal UI."
fi

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT INT TERM

# Check if we are running inside an already cloned / extracted openpreset folder
SELF_DIR=$(cd -P "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "${SELF_DIR}" ] && [ -f "${SELF_DIR}/router/router_engine.sh" ]; then
    printf '%s\n' "📦 Using local openpreset source files..."
    SRC_DIR="${SELF_DIR}"
else
    printf '%s\n' "📥 Downloading release tarball: ${TARBALL_NAME}..."
    TARBALL_PATH="${TMP_DIR}/openpreset.tar.gz"
    
    if ! curl -fsSL "${TARBALL_URL}" -o "${TARBALL_PATH}" 2>/dev/null; then
        # Fallback to downloading raw repository archive if release tarball is not yet attached
        ALT_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
        printf '%s\n' "ℹ️  Release asset not found. Downloading main branch source archive..."
        curl -fsSL "${ALT_URL}" -o "${TARBALL_PATH}"
    fi

    printf '%s\n' "📦 Extracting package..."
    tar -xzf "${TARBALL_PATH}" -C "${TMP_DIR}"
    SRC_DIR=$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n1)
fi

# Prepare target paths
mkdir -p "${BIN_DIR}" "${SHARE_DIR}"

# Copy router engine libraries
printf '%s\n' "📂 Installing libraries to ${SHARE_DIR}..."
rm -rf "${SHARE_DIR}/router"
cp -r "${SRC_DIR}/router" "${SHARE_DIR}/router"

# Copy binary launchers
printf '%s\n' "⚡ Installing launchers to ${BIN_DIR}..."
for launcher in cr kr hr or pr clr openpreset; do
    if [ -f "${SRC_DIR}/launchers/${launcher}" ]; then
        cp "${SRC_DIR}/launchers/${launcher}" "${BIN_DIR}/${launcher}"
        chmod +x "${BIN_DIR}/${launcher}"
        printf '%s\n' "  ✓ ${BIN_DIR}/${launcher}"
    fi
done

printf '%s\n' "========================================================"
printf '%s\n' "✅ openpreset installed successfully!"
printf '%s\n' "========================================================"
printf '%s\n' ""
printf '%s\n' "Available Launchers:"
printf '%s\n' "  cr       -> Claude Code"
printf '%s\n' "  kr       -> Kilo Code"
printf '%s\n' "  hr       -> Hermes Agent"
printf '%s\n' "  or       -> OpenClaw"
printf '%s\n' "  pr       -> Pi Agent"
printf '%s\n' "  clr      -> Cline"
printf '%s\n' "  openpreset -> Suite manager & auto-updater (run 'openpreset update')"
printf '%s\n' ""

# Check PATH
case ":${PATH}:" in
    *:"${BIN_DIR}":*) ;;
    *)
        printf '%s\n' "⚠️  Notice: ${BIN_DIR} is not in your PATH."
        printf '%s\n' "Add it to your shell configuration (~/.bashrc or ~/.zshrc):"
        printf '%s\n' "    export PATH=\"${BIN_DIR}:\$PATH\""
        printf '%s\n' ""
        ;;
esac
