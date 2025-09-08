#!/bin/bash

set -e

# Check if version is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.5.0"
    exit 1
fi

VERSION=$1
# Remove 'v' prefix if present for consistency
VERSION_NO_V=${VERSION#v}
ARCH="linux_amd64"
SCARB_ARCH="x86_64-unknown-linux-gnu"
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
    KATANA_VERSION=$(jq -r ".[\"$VERSION_NO_V\"].katana[-1]" "$TEMP_DIR/versions.json" 2>/dev/null || echo "")
    TORII_VERSION=$(jq -r ".[\"$VERSION_NO_V\"].torii[-1]" "$TEMP_DIR/versions.json" 2>/dev/null || echo "")
else
    # Fallback to python
    KATANA_VERSION=$(python3 -c "
import json, sys
with open('$TEMP_DIR/versions.json') as f:
    data = json.load(f)
    if '$VERSION_NO_V' in data and 'katana' in data['$VERSION_NO_V']:
        print(data['$VERSION_NO_V']['katana'][-1])
" 2>/dev/null || echo "")

    TORII_VERSION=$(python3 -c "
import json, sys
with open('$TEMP_DIR/versions.json') as f:
    data = json.load(f)
    if '$VERSION_NO_V' in data and 'torii' in data['$VERSION_NO_V']:
        print(data['$VERSION_NO_V']['torii'][-1])
" 2>/dev/null || echo "")
fi

# Check if versions were found
if [ -z "$KATANA_VERSION" ] || [ -z "$TORII_VERSION" ]; then
    echo "Error: Version $VERSION_NO_V not found in versions.json or missing component versions"
    exit 1
fi

echo "Found component versions:"
echo "  Katana: $KATANA_VERSION"
echo "  Torii: $TORII_VERSION"

# Fetch .tool-versions file to get scarb version
echo "Fetching scarb version from .tool-versions..."
TOOL_VERSIONS_URL="https://raw.githubusercontent.com/dojoengine/dojo/refs/tags/v${VERSION_NO_V}/.tool-versions"
if ! curl -sL "$TOOL_VERSIONS_URL" -o "$TEMP_DIR/tool-versions" 2>/dev/null || [ ! -s "$TEMP_DIR/tool-versions" ]; then
    # Try without 'v' prefix
    TOOL_VERSIONS_URL="https://raw.githubusercontent.com/dojoengine/dojo/refs/tags/${VERSION_NO_V}/.tool-versions"
    curl -sL "$TOOL_VERSIONS_URL" -o "$TEMP_DIR/tool-versions" 2>/dev/null || true
fi

# Extract scarb version
SCARB_VERSION=""
if [ -f "$TEMP_DIR/tool-versions" ]; then
    SCARB_VERSION=$(grep "^scarb " "$TEMP_DIR/tool-versions" | awk '{print $2}' || echo "")
fi

if [ -n "$SCARB_VERSION" ]; then
    echo "  Scarb: $SCARB_VERSION"
else
    echo "  Scarb: not found in .tool-versions (optional)"
fi

# Download and extract dojo (sozo)
echo "Downloading Dojo (sozo)..."
DOJO_URL="https://github.com/dojoengine/dojo/releases/download/v${VERSION_NO_V}/dojo_v${VERSION_NO_V}_${ARCH}.tar.gz"
if ! curl -sL "$DOJO_URL" -o "$TEMP_DIR/dojo.tar.gz"; then
    # Try without 'v' prefix
    DOJO_URL="https://github.com/dojoengine/dojo/releases/download/${VERSION_NO_V}/dojo_${VERSION_NO_V}_${ARCH}.tar.gz"
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

# Download and extract scarb if version was found
if [ -n "$SCARB_VERSION" ]; then
    echo "Downloading Scarb..."

    # Check if it's a regular version or dev/nightly
    if [[ "$SCARB_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Regular version from main scarb repo
        SCARB_URL="https://github.com/software-mansion/scarb/releases/download/v${SCARB_VERSION}/scarb-v${SCARB_VERSION}-${SCARB_ARCH}.tar.gz"
        if ! curl -sL "$SCARB_URL" -o "$TEMP_DIR/scarb.tar.gz"; then
            # Try without 'v' prefix
            SCARB_URL="https://github.com/software-mansion/scarb/releases/download/${SCARB_VERSION}/scarb-${SCARB_VERSION}-${SCARB_ARCH}.tar.gz"
            curl -sL "$SCARB_URL" -o "$TEMP_DIR/scarb.tar.gz"
        fi
    else
        # Dev/nightly version from scarb-nightlies repo
        SCARB_URL="https://github.com/software-mansion/scarb-nightlies/releases/download/${SCARB_VERSION}/scarb-${SCARB_VERSION}-${SCARB_ARCH}.tar.gz"
        curl -sL "$SCARB_URL" -o "$TEMP_DIR/scarb.tar.gz"
    fi

    echo "Extracting Scarb..."
    tar -xzf "$TEMP_DIR/scarb.tar.gz" -C "$TEMP_DIR"

    # Scarb has the binary inside a folder structure, find it
    SCARB_BIN=$(find "$TEMP_DIR" -type f -name "scarb" -executable | head -1)
    if [ -n "$SCARB_BIN" ]; then
        echo "  Found scarb binary at: $SCARB_BIN"
    fi
fi

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

# Install scarb if it was found
if [ -n "$SCARB_BIN" ]; then
    echo "  Installing scarb..."
    sudo cp "$SCARB_BIN" "$INSTALL_DIR/scarb"
    sudo chmod +x "$INSTALL_DIR/scarb"
fi

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

# Check scarb if it was installed
if [ -n "$SCARB_VERSION" ]; then
    if command -v scarb &> /dev/null; then
        echo "✓ scarb installed successfully"
        scarb --version 2>/dev/null || true
    else
        echo "✗ scarb not found in PATH"
    fi
fi

echo ""
echo "Dojo $VERSION installation complete!"
