#!/bin/bash

set -e

# Check if version is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.5.0"
    exit 1
fi

VERSION=$1
ARCH="linux_amd64"
INSTALL_DIR="/usr/local/bin"

# Ensure install directory exists and is in PATH
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
    export PATH="/usr/local/bin:$PATH"
fi

echo "Installing Dojo version: $VERSION"

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download versions.json to get component versions
echo "Fetching version mappings..."
curl -sL "https://raw.githubusercontent.com/dojoengine/dojo/refs/heads/main/versions.json" -o "$TEMP_DIR/versions.json"

# Extract katana and torii versions using jq (or python as fallback)
if command -v jq &> /dev/null; then
    # Use jq if available
    KATANA_VERSION=$(jq -r ".[\"$VERSION\"].katana[-1]" "$TEMP_DIR/versions.json" 2>/dev/null || echo "")
    TORII_VERSION=$(jq -r ".[\"$VERSION\"].torii[-1]" "$TEMP_DIR/versions.json" 2>/dev/null || echo "")
else
    # Fallback to python
    KATANA_VERSION=$(python3 -c "
import json, sys
with open('$TEMP_DIR/versions.json') as f:
    data = json.load(f)
    if '$VERSION' in data and 'katana' in data['$VERSION']:
        print(data['$VERSION']['katana'][-1])
" 2>/dev/null || echo "")

    TORII_VERSION=$(python3 -c "
import json, sys
with open('$TEMP_DIR/versions.json') as f:
    data = json.load(f)
    if '$VERSION' in data and 'torii' in data['$VERSION']:
        print(data['$VERSION']['torii'][-1])
" 2>/dev/null || echo "")
fi

# Check if versions were found
if [ -z "$KATANA_VERSION" ] || [ -z "$TORII_VERSION" ]; then
    echo "Error: Version $VERSION not found in versions.json or missing component versions"
    exit 1
fi

echo "Found component versions:"
echo "  Katana: $KATANA_VERSION"
echo "  Torii: $TORII_VERSION"

# Download and extract dojo (sozo)
echo "Downloading Dojo (sozo)..."
DOJO_URL="https://github.com/dojoengine/dojo/releases/download/v${VERSION}/dojo_v${VERSION}_${ARCH}.tar.gz"
if ! curl -sL "$DOJO_URL" -o "$TEMP_DIR/dojo.tar.gz"; then
    # Try without 'v' prefix
    DOJO_URL="https://github.com/dojoengine/dojo/releases/download/${VERSION}/dojo_${VERSION}_${ARCH}.tar.gz"
    curl -sL "$DOJO_URL" -o "$TEMP_DIR/dojo.tar.gz"
fi

echo "Extracting Dojo..."
tar -xzf "$TEMP_DIR/dojo.tar.gz" -C "$TEMP_DIR"

# Download and extract katana
echo "Downloading Katana..."
KATANA_URL="https://github.com/dojoengine/katana/releases/download/v${KATANA_VERSION}/katana_v${KATANA_VERSION}_${ARCH}.tar.gz"
if ! curl -sL "$KATANA_URL" -o "$TEMP_DIR/katana.tar.gz"; then
    # Try without 'v' prefix
    KATANA_URL="https://github.com/dojoengine/katana/releases/download/${KATANA_VERSION}/katana_${KATANA_VERSION}_${ARCH}.tar.gz"
    curl -sL "$KATANA_URL" -o "$TEMP_DIR/katana.tar.gz"
fi

echo "Extracting Katana..."
tar -xzf "$TEMP_DIR/katana.tar.gz" -C "$TEMP_DIR"

# Download and extract torii
echo "Downloading Torii..."
TORII_URL="https://github.com/dojoengine/torii/releases/download/v${TORII_VERSION}/torii_v${TORII_VERSION}_${ARCH}.tar.gz"
if ! curl -sL "$TORII_URL" -o "$TEMP_DIR/torii.tar.gz"; then
    # Try without 'v' prefix
    TORII_URL="https://github.com/dojoengine/torii/releases/download/${TORII_VERSION}/torii_${TORII_VERSION}_${ARCH}.tar.gz"
    curl -sL "$TORII_URL" -o "$TEMP_DIR/torii.tar.gz"
fi

echo "Extracting Torii..."
tar -xzf "$TEMP_DIR/torii.tar.gz" -C "$TEMP_DIR"

# Install binaries to PATH
echo "Installing binaries to $INSTALL_DIR..."

# Find and install executables
for binary in sozo katana torii; do
    if [ -f "$TEMP_DIR/$binary" ]; then
        echo "  Installing $binary..."
        sudo mv "$TEMP_DIR/$binary" "$INSTALL_DIR/"
        sudo chmod +x "$INSTALL_DIR/$binary"
    else
        echo "  Warning: $binary not found in extracted files"
    fi
done

# Verify installation
echo ""
echo "Installation complete. Verifying..."
for binary in sozo katana torii; do
    if command -v $binary &> /dev/null; then
        echo "✓ $binary installed successfully"
        $binary --version 2>/dev/null || true
    else
        echo "✗ $binary not found in PATH"
    fi
done

echo ""
echo "Dojo $VERSION installation complete!"
