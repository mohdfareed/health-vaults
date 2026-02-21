#!/usr/bin/env sh

if [ "$1" = "-b" ] || [ "$1" = "--beta" ]; then
    echo "Building beta..."
    configuration=debug
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
elif [ "$1" = "-d" ] || [ "$1" = "--debug" ]; then
    echo "Building debug..."
    configuration=debug
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
else
    echo "Building release..."
    configuration=release
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo
echo "Building HealthVaults..."
swift build --configuration $configuration

echo
echo "Building HealthVaults (Xcode)..."
xcodebuild -scheme HealthVaults -destination 'generic/platform=iOS Simulator' \
    build-for-testing 2>&1 | tail -n 2

echo "Build complete."
unset DEVELOPER_DIR
