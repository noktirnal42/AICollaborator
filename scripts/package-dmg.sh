#!/bin/bash
set -euo pipefail

# package-dmg.sh — Build AICollaborator and package as a release DMG
# Requirements: macOS 15+, Xcode 16+, Swift 6
# Usage: ./scripts/package-dmg.sh [--configuration Release|Debug] [--output-dir <path>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="AICollaborator"
BUNDLE_ID="com.noktirnal42.AICollaborator"
VERSION="0.1.0"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
CONFIGURATION="Release"
OUTPUT_DIR="${PROJECT_DIR}/build/release"
DMG_NAME="${APP_NAME}-${VERSION}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            DMG_NAME="${APP_NAME}-${VERSION}"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--configuration Release|Debug] [--output-dir <path>] [--version <ver>]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== AICollaborator Release Packager ==="
echo "Version:       ${VERSION}"
echo "Build:         ${BUILD_NUMBER}"
echo "Configuration: ${CONFIGURATION}"
echo "Output:        ${OUTPUT_DIR}"
echo ""

# Ensure we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: DMG packaging requires macOS. This script cannot run on $(uname)."
    exit 1
fi

# Check for required tools
command -v swift >/dev/null 2>&1 || { echo "Error: swift not found"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "Error: xcodebuild not found (install Xcode)"; exit 1; }
command -v hdiutil >/dev/null 2>&1 || { echo "Error: hdiutil not found"; exit 1; }

# Clean and create output directories
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

BUILD_DIR="${OUTPUT_DIR}/build"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
DMG_STAGING="${OUTPUT_DIR}/dmg-staging"
CLI_BIN="${OUTPUT_DIR}/ai-collaborator"

echo ">>> Step 1: Building Swift package (${CONFIGURATION})..."
swift build \
    --package-path "${PROJECT_DIR}" \
    -c "$(echo "${CONFIGURATION}" | tr '[:upper:]' '[:lower:]')" \
    --build-path "${BUILD_DIR}"

echo ">>> Step 2: Creating application bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy the CLI binary as the main executable
SWIFT_BUILD_CONFIG="$(echo "${CONFIGURATION}" | tr '[:upper:]' '[:lower:]')"
cp "${BUILD_DIR}/${SWIFT_BUILD_CONFIG}/AICollaboratorCLI" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy CLI binary separately for command-line use
cp "${BUILD_DIR}/${SWIFT_BUILD_CONFIG}/AICollaboratorCLI" "${CLI_BIN}"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>AI Collaborator</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 noktirnal42. MIT License.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

# Copy app icon if it exists
if [ -f "${PROJECT_DIR}/Sources/Resources/assets/images/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Sources/Resources/assets/images/AppIcon.icns" \
       "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    # Add icon reference to Info.plist
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
fi

# Copy logo as a resource
if [ -f "${PROJECT_DIR}/Sources/Resources/assets/images/AICollaborator_logo.png" ]; then
    cp "${PROJECT_DIR}/Sources/Resources/assets/images/AICollaborator_logo.png" \
       "${APP_BUNDLE}/Contents/Resources/"
fi

echo ">>> Step 3: Staging DMG contents..."
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
cp "${CLI_BIN}" "${DMG_STAGING}/ai-collaborator"

# Create a README for the DMG
cat > "${DMG_STAGING}/README.txt" <<README
AI Collaborator v${VERSION}
========================

Installation:
  1. Drag AICollaborator.app to your Applications folder.
  2. Optionally, copy 'ai-collaborator' to /usr/local/bin/ for CLI access.

CLI Usage:
  ai-collaborator execute "your query here"
  ai-collaborator --help

Requirements:
  - macOS 15.0 or later

For more information:
  https://github.com/noktirnal42/AICollaborator

License: MIT
README

# Create Applications symlink for drag-install
ln -sf /Applications "${DMG_STAGING}/Applications"

echo ">>> Step 4: Creating DMG..."
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "${DMG_PATH}"

echo ">>> Step 5: Cleanup..."
rm -rf "${DMG_STAGING}" "${BUILD_DIR}"

# Calculate checksums
echo ">>> Generating checksums..."
CHECKSUM_FILE="${OUTPUT_DIR}/${DMG_NAME}-checksums.txt"
pushd "${OUTPUT_DIR}" > /dev/null
shasum -a 256 "${DMG_NAME}.dmg" > "${CHECKSUM_FILE}"
shasum -a 256 "ai-collaborator" >> "${CHECKSUM_FILE}"
popd > /dev/null

echo ""
echo "=== Build Complete ==="
echo "DMG:       ${DMG_PATH}"
echo "CLI:       ${CLI_BIN}"
echo "App:       ${APP_BUNDLE}"
echo "Checksums: ${CHECKSUM_FILE}"
echo ""
echo "DMG size: $(du -h "${DMG_PATH}" | cut -f1)"
cat "${CHECKSUM_FILE}"
