#!/usr/bin/env sh
# install.sh — One-command installer for openpreset router suite.
# Usage: curl -fsSL https://raw.githubusercontent.com/ZaituDev/OpenPreset/main/install.sh | sh
set -eu

VERSION="2.2.0"
REPO="zaidsubhani135/claude-router"
TARBALL_NAME="openpreset-v${VERSION}.tar.gz"
TARBALL_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${TARBALL_NAME}"

# Determine target directories (User vs System)
if [ "$(id -u)" -eq 0 ]; then
    BIN_DIR="/usr/local/bin"
    SHARE_DIR="/usr/local/share/openpreset"
else
    BIN_DIR="${HOME}/.local/bin"
    SHARE_DIR="${HOME}/.local/share/openpreset"
fi

# Dependency check
printf '%s\n' "Checking dependencies..."
for dep in curl jq; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        printf '%s\n' "Error: Missing required dependency: $dep. Please install $dep and re-run." >&2
        exit 1
    fi
done
if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "  ✓ fzf found (enhanced UI enabled)"
else
    printf '%s\n' "  fzf not found (will fallback to text menus)"
fi

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT INT TERM

# Check if we are running inside an already cloned / extracted openpreset folder
SELF_DIR=$(cd -P "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "${SELF_DIR}" ] && [ -f "${SELF_DIR}/router/router_engine.sh" ]; then
    SRC_DIR="${SELF_DIR}"
else
    TARBALL_PATH="${TMP_DIR}/openpreset.tar.gz"
    
    if ! curl -fsSL "${TARBALL_URL}" -o "${TARBALL_PATH}" 2>/dev/null; then
        # Fallback to downloading raw repository archive if release tarball is not yet attached
        ALT_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
        if ! curl -fsSL "${ALT_URL}" -o "${TARBALL_PATH}" 2>/dev/null; then
            printf '%s\n' "Error: Failed to download openpreset release package." >&2
            exit 1
        fi
    fi

    printf '%s\n' "Extracting package..."
    tar -xzf "${TARBALL_PATH}" -C "${TMP_DIR}"
    SRC_DIR=$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n1)
fi

# Prepare target paths
mkdir -p "${BIN_DIR}" "${SHARE_DIR}"

# Copy router engine libraries & assets
rm -rf "${SHARE_DIR}/router" "${SHARE_DIR}/assets"
cp -r "${SRC_DIR}/router" "${SHARE_DIR}/router"
if [ -d "${SRC_DIR}/assets" ]; then
    cp -r "${SRC_DIR}/assets" "${SHARE_DIR}/assets"
fi

# Reset last_seen_version so first run shows lbanner
rm -f "${XDG_CONFIG_HOME:-${HOME}/.config}/openpreset/last_seen_version" 2>/dev/null || true

# Copy binary launchers
printf '%s\n' "Installing launchers to ${BIN_DIR}..."
for launcher in cr kr hr or pr clr openpreset; do
    if [ -f "${SRC_DIR}/launchers/${launcher}" ]; then
        cp "${SRC_DIR}/launchers/${launcher}" "${BIN_DIR}/${launcher}"
        chmod +x "${BIN_DIR}/${launcher}"
    fi
done

printf '%s\n' "openpreset v${VERSION} installed to ${BIN_DIR}"
printf '%s\n' "Run 'openpreset help' to get started."

# Check PATH
case ":${PATH}:" in
    *:"${BIN_DIR}":*) ;;
    *)
        printf '%s\n' "Notice: ${BIN_DIR} is not in your PATH. Add export PATH=\"${BIN_DIR}:\$PATH\" to your shell config."
        ;;
esac

