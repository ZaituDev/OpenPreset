#!/usr/bin/env sh
# package.sh — Builds openpreset-v1.0.0.tar.gz release package and checksums.
set -eu

SCRIPT_DIR=$(cd -P "$(dirname "$0")" && pwd)
VERSION="${1:-2.0.0}"
PACKAGE_NAME="openpreset-v${VERSION}"
DIST_DIR="${SCRIPT_DIR}/dist"
BUILD_DIR="${DIST_DIR}/${PACKAGE_NAME}"
TARBALL="openpreset-v${VERSION}.tar.gz"

printf '%s\n' "📦 Packaging ${PACKAGE_NAME}..."

rm -rf "${DIST_DIR}"
mkdir -p "${BUILD_DIR}"

cp -r "${SCRIPT_DIR}/launchers" "${BUILD_DIR}/"
cp -r "${SCRIPT_DIR}/router" "${BUILD_DIR}/"
cp -r "${SCRIPT_DIR}/assets" "${BUILD_DIR}/" 2>/dev/null || true
cp -r "${SCRIPT_DIR}/extras" "${BUILD_DIR}/" 2>/dev/null || true
cp "${SCRIPT_DIR}/install.sh" "${BUILD_DIR}/" 2>/dev/null || true
cp "${SCRIPT_DIR}/README.md" "${BUILD_DIR}/"
cp "${SCRIPT_DIR}/CHANGELOG.md" "${BUILD_DIR}/" 2>/dev/null || true
cp "${SCRIPT_DIR}/LICENSE" "${BUILD_DIR}/" 2>/dev/null || true

cd "${DIST_DIR}"
tar -czf "${TARBALL}" "${PACKAGE_NAME}"

# Clean up temporary extracted directory
rm -rf "${BUILD_DIR}"

# Generate checksums.txt
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${TARBALL}" > checksums.txt
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${TARBALL}" > checksums.txt
fi

printf '%s\n' "✓ Release tarball & checksum created in dist/:"
printf '%s\n' "   - ${TARBALL} ($(du -h "${TARBALL}" | cut -f1))"
printf '%s\n' "   - checksums.txt"
printf '%s\n' ""
cat checksums.txt
