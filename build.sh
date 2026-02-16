#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ============================================================================
# Step 1: Fetch NVIDIA Kit SDK build tools from isaacsim-app-template if missing
# ============================================================================

ISAACSIM_APP_TEMPLATE_REPO="https://github.com/isaac-sim/isaacsim-app-template.git"
ISAACSIM_APP_TEMPLATE_TAG="v5.1.0"

if [ ! -d "$SCRIPT_DIR/tools" ] || [ ! -f "$SCRIPT_DIR/repo.sh" ]; then
    echo "Fetching NVIDIA Kit SDK build tools from isaacsim-app-template..."
    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 --branch "$ISAACSIM_APP_TEMPLATE_TAG" "$ISAACSIM_APP_TEMPLATE_REPO" "$TEMP_DIR"

    # Copy build tools
    if [ -d "$TEMP_DIR/tools" ]; then
        cp -r "$TEMP_DIR/tools" "$SCRIPT_DIR/tools"
        echo "Copied tools/ directory."
    else
        echo "Error: tools/ directory not found in isaacsim-app-template."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Copy repo.sh bootstrap script
    if [ -f "$TEMP_DIR/repo.sh" ]; then
        cp "$TEMP_DIR/repo.sh" "$SCRIPT_DIR/repo.sh"
        chmod +x "$SCRIPT_DIR/repo.sh"
        echo "Copied repo.sh."
    else
        echo "Error: repo.sh not found in isaacsim-app-template."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    rm -rf "$TEMP_DIR"
    echo "Build tools fetched successfully."
fi

# ============================================================================
# Step 2: Download and set up Cesium for Omniverse extension
# ============================================================================

TARGET_DIR="$SCRIPT_DIR/source/extensions"
AEROSIM_EXTENSION="aerosim.omniverse.extension"

CESIUM_FOLDER1="cesium.omniverse"
CESIUM_FOLDER2="cesium.usd.plugins"
ZIP_URL="https://github.com/CesiumGS/cesium-omniverse/releases/download/v0.27.0/CesiumGS-cesium-omniverse-linux-x86_64-v0.27.0.zip"
ZIP_FILE="$TARGET_DIR/cesium_omniverse.zip"
EXTRACT_PATH="$TARGET_DIR"
SETUP_CESIUM=true

# Check if the folders exist
if [ -d "$TARGET_DIR/$CESIUM_FOLDER1" ] && [ -d "$TARGET_DIR/$CESIUM_FOLDER2" ]; then
    echo "Cesium extension folders already exist. No need to download."
    SETUP_CESIUM=false
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Download the ZIP file if the folders don't exist
if [ "$SETUP_CESIUM" = true ]; then
    echo "Downloading Cesium Omniverse file..."
    if curl -L -o "$ZIP_FILE" "$ZIP_URL"; then
        echo "File downloaded successfully."

        # Extract the ZIP file
        echo "Extracting the file to $EXTRACT_PATH..."
        if unzip -o "$ZIP_FILE" -d "$EXTRACT_PATH"; then
            echo "Extraction completed successfully."
        else
            echo "Error: Extraction failed."
            exit 1
        fi

        # Check if extraction was successful
        if [ -d "$EXTRACT_PATH/$CESIUM_FOLDER1" ]; then
            echo "Extraction verified."
        else
            echo "Error: The folder $CESIUM_FOLDER1 was not found after extraction."
        fi

        echo -n "repo_build.prebuild_link { \"mdl\", ext.target_dir..\"/mdl\" }" >> "$TARGET_DIR/$CESIUM_FOLDER1/premake5.lua"
        echo -n "repo_build.prebuild_link { \"vendor\", ext.target_dir..\"/vendor\" }" >> "$TARGET_DIR/$CESIUM_FOLDER1/premake5.lua"

        # Delete the ZIP file after extraction
        rm -f "$ZIP_FILE"
        echo "ZIP file deleted."
    else
        echo "Error: The file could not be downloaded."
        exit 1
    fi
fi

# ============================================================================
# Step 3: Clone aerosim-omniverse-extension if not present
# ============================================================================

AEROSIM_EXTENSION_REPO="https://github.com/edufford/aerosim-omniverse-extension.git"

if [ ! -d "$TARGET_DIR/$AEROSIM_EXTENSION" ]; then
    echo "Cloning aerosim-omniverse-extension..."
    git clone "$AEROSIM_EXTENSION_REPO" "$TARGET_DIR/$AEROSIM_EXTENSION"
    echo "aerosim-omniverse-extension cloned successfully."
else
    echo "aerosim-omniverse-extension already exists."
fi

# ============================================================================
# Step 4: Copy aerosim-world-link library
# ============================================================================

echo "AEROSIM_WORLD_LINK_LIB is set to: $AEROSIM_WORLD_LINK_LIB"
mkdir -p "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
cp -r "$AEROSIM_WORLD_LINK_LIB"/* "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
echo "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib" > "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim_world_link_lib_path.txt"

# ============================================================================
# Step 5: Build with repo.sh
# ============================================================================

source "$SCRIPT_DIR/repo.sh" build "$@" || exit $?
