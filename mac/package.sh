#!/bin/bash
set -euo pipefail

APP_NAME="WSNH"
APP_BUNDLE="${APP_NAME}.app"
ZIP_NAME="${APP_NAME}.zip"

echo "==> Running build.sh..."
./build.sh

if [ ! -d "$APP_BUNDLE" ]; then
  echo "Error: ${APP_BUNDLE} not found after build. Check the build.sh output above."
  exit 1
fi

echo ""
echo "==> Zipping ${APP_BUNDLE} for distribution..."
rm -f "$ZIP_NAME"
# ditto preserves the .app bundle structure/metadata correctly, unlike plain zip.
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_NAME"

echo ""
echo "Done. ${ZIP_NAME} is ready in this folder."
echo "Share it along with README.md — colleagues just need to unzip, open it,"
echo "and follow the setup steps in the README (no building required on their end)."
