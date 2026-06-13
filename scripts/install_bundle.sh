#!/bin/bash
set -e

#BASEDIR="${0:a:h}"

if [ -z "$AUTHBUNDLE" ]; then
    echo "AUTHBUNDLE must be set" >&2
    exit 1
fi

BUILT_AUTH_BUNDLE="$AUTHBUNDLE/build/BengalLogin.bundle"
AUTH_PLUGIN_FOLDER="/Library/Security/SecurityAgentPlugins"

if [ ! -e "$BUILT_AUTH_BUNDLE" ]; then
    echo "expected built auth bundle not found at $BUILT_AUTH_BUNDLE" >&2
    exit 1
fi

sudo mkdir -p "$AUTH_PLUGIN_FOLDER"
sudo rm -rf "$AUTH_PLUGIN_FOLDER/BengalLogin.bundle"
sudo cp -a "$BUILT_AUTH_BUNDLE" "$AUTH_PLUGIN_FOLDER"