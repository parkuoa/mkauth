#!/bin/bash
set -e

BINARY=/tmp/UIAuthBundleTest
#BASEDIR="${0:a:h}"
BASEDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [ -z "$AUTHBUNDLE" ]; then
    echo "AUTHBUNDLE must be set" >&2
    exit 1
fi
RESOURCES_DIR="$(dirname "$BINARY")/Resources"

echo "compiling given login UI..."
swiftc "$AUTHBUNDLE/core/LoginUI.swift" "$BASEDIR/test_login_ui.swift" \
    "$AUTHBUNDLE/core/SettingsManager.swift" \
    "$AUTHBUNDLE/core/BundleLog.swift" \
    -framework OpenDirectory \
    -o "$BINARY"

mkdir -p "$RESOURCES_DIR"
find "$AUTHBUNDLE/Resources" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' resource; do
    cp "$resource" "$RESOURCES_DIR"
done

echo "done, running login UI"
"$BINARY"
