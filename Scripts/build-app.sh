#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
configuration="${CONFIGURATION:-release}"
app_directory="${project_directory}/dist/InputKeeper.app"

cd "${project_directory}"

swift build -c "${configuration}" --disable-sandbox
binary_directory="$(swift build -c "${configuration}" --show-bin-path --disable-sandbox)"

mkdir -p "${app_directory}/Contents/MacOS"
cp "${binary_directory}/InputKeeper" "${app_directory}/Contents/MacOS/InputKeeper"
cp "${project_directory}/Resources/Info.plist" "${app_directory}/Contents/Info.plist"

codesign --force --sign - "${app_directory}"

echo "已生成 ${app_directory}"
