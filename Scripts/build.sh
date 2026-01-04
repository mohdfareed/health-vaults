#!/usr/bin/env sh

if [ "$1" = "-b" ] || [ "$1" = "--beta" ]; then
    echo "Building beta..."
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
else
    echo "Building release..."
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

swift build
unset DEVELOPER_DIR
echo "Build complete."
