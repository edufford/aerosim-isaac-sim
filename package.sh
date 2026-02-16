#!/bin/bash

# Exit on error
set -e

# Set default configuration as release
PACKAGE_CONFIG="release"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            PACKAGE_CONFIG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

PACKAGE_NAME="aerosim-isaac-sim-$PACKAGE_CONFIG.zip"
BUILD_FOLDER="$AEROSIM_ISAAC_SIM_ROOT/package-$PACKAGE_CONFIG"

pushd "$AEROSIM_ISAAC_SIM_ROOT" > /dev/null

# Build the kit app
./build.sh --config "$PACKAGE_CONFIG"

# Package the kit app
./repo.sh package -c "$PACKAGE_CONFIG" -n "$PACKAGE_NAME"

# Remove auto-generated part of package name
mv _build/packages/$PACKAGE_NAME*.zip _build/packages/$PACKAGE_NAME

# Extract the package to the target output folder
mkdir -p "$BUILD_FOLDER"
unzip -o "$AEROSIM_ISAAC_SIM_ROOT/_build/packages/$PACKAGE_NAME" -d "$BUILD_FOLDER"
rm "$AEROSIM_ISAAC_SIM_ROOT/_build/packages/$PACKAGE_NAME"

echo "Package created and output to: $BUILD_FOLDER"

popd > /dev/null
