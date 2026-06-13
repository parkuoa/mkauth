#!/bin/bash
set -e

BINARY=/tmp/BengalLoginUI_Test
#BASEDIR="${0:a:h}"
BASEDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RESOURCES_DIR="$(dirname "$BINARY")/Resources"

echo "compiling present login UI..."
swiftc ${BASEDIR}/../AuthorizationBundle/core/LoginUI.swift ${BASEDIR}/test_login_ui.swift \
    ${BASEDIR}/../AuthorizationBundle/core/SettingsManager.swift \
    ${BASEDIR}/../AuthorizationBundle/core/BundleLog.swift \
    -framework OpenDirectory \
    -o "$BINARY"

mkdir -p "$RESOURCES_DIR"
cp ${BASEDIR}/../AuthorizationBundle/Resources/Comfortaa-*.ttf "$RESOURCES_DIR/"

echo "done, running login UI"
"$BINARY"
