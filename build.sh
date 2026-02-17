#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TARGET_DIR="$SCRIPT_DIR/source/extensions"

# ============================================================================
# Step 1: Download Cesium for Omniverse extension (if not present)
# ============================================================================

CESIUM_FOLDER1="cesium.omniverse"
CESIUM_FOLDER2="cesium.usd.plugins"
ZIP_URL="https://github.com/CesiumGS/cesium-omniverse/releases/download/v0.27.0/CesiumGS-cesium-omniverse-linux-x86_64-v0.27.0.zip"

if [ ! -d "$TARGET_DIR/$CESIUM_FOLDER1" ] || [ ! -d "$TARGET_DIR/$CESIUM_FOLDER2" ]; then
    echo "Downloading Cesium for Omniverse..."
    mkdir -p "$TARGET_DIR"
    ZIP_FILE="$TARGET_DIR/cesium_omniverse.zip"

    curl -L -o "$ZIP_FILE" "$ZIP_URL"
    unzip -o "$ZIP_FILE" -d "$TARGET_DIR"
    rm -f "$ZIP_FILE"

    # Patch Cesium premake5.lua with mdl and vendor links
    echo -n "repo_build.prebuild_link { \"mdl\", ext.target_dir..\"/mdl\" }" >> "$TARGET_DIR/$CESIUM_FOLDER1/premake5.lua"
    echo -n "repo_build.prebuild_link { \"vendor\", ext.target_dir..\"/vendor\" }" >> "$TARGET_DIR/$CESIUM_FOLDER1/premake5.lua"

    echo "Cesium for Omniverse downloaded."
else
    echo "Cesium for Omniverse already present."
fi

# ============================================================================
# Step 2: Clone aerosim-omniverse-extension (if not present)
# ============================================================================

AEROSIM_EXTENSION="aerosim.omniverse.extension"
AEROSIM_EXTENSION_REPO="https://github.com/edufford/aerosim-omniverse-extension.git"

if [ ! -d "$TARGET_DIR/$AEROSIM_EXTENSION" ]; then
    echo "Cloning aerosim-omniverse-extension..."
    git clone -b claude/isaac_sim "$AEROSIM_EXTENSION_REPO" "$TARGET_DIR/$AEROSIM_EXTENSION"
    echo "aerosim-omniverse-extension cloned."
else
    echo "aerosim-omniverse-extension already present."
fi

# ============================================================================
# Step 3: Copy aerosim-world-link library
# ============================================================================

if [ -z "$AEROSIM_WORLD_LINK_LIB" ]; then
    echo "Warning: AEROSIM_WORLD_LINK_LIB not set. Skipping library copy."
else
    echo "Copying aerosim-world-link library from $AEROSIM_WORLD_LINK_LIB"
    mkdir -p "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
    cp -r "$AEROSIM_WORLD_LINK_LIB"/* "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
    echo "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib" > "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim_world_link_lib_path.txt"
fi

# ============================================================================
# Step 4: Build with repo.sh
# ============================================================================

source "$SCRIPT_DIR/repo.sh" build "$@" || exit $?
