#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
configuration="${CONFIGURATION:-release}"
app_directory="${project_directory}/dist/InputKeeper.app"
configuration_file="${project_directory}/Config.xcconfig"
asset_output_directory="$(mktemp -d /private/tmp/inputkeeper-assets.XXXXXX)"

configuration_value() {
    local key="$1"
    awk -F "=" -v key="${key}" '
        $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
            value = $2
            sub(/^[[:space:]]*/, "", value)
            sub(/[[:space:]]*$/, "", value)
            print value
            exit
        }
    ' "${configuration_file}"
}

cleanup() {
    rm -rf -- "${asset_output_directory}"
}

trap cleanup EXIT

cd "${project_directory}"

version="$(configuration_value VERSION)"
build_number="$(configuration_value BUILD_NUMBER)"

if [[ -z "${version}" || -z "${build_number}" ]]; then
    echo "无法从 ${configuration_file} 读取 VERSION 或 BUILD_NUMBER" >&2
    exit 1
fi

swift build -c "${configuration}" --disable-sandbox
binary_directory="$(swift build -c "${configuration}" --show-bin-path --disable-sandbox)"

mkdir -p "${app_directory}/Contents/MacOS" "${app_directory}/Contents/Resources"
cp "${binary_directory}/InputKeeper" "${app_directory}/Contents/MacOS/InputKeeper"
cp "${project_directory}/Resources/Info.plist" "${app_directory}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "${version}" "${app_directory}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${build_number}" "${app_directory}/Contents/Info.plist"

xcrun actool "${project_directory}/Resources/Assets.xcassets" \
    --compile "${app_directory}/Contents/Resources" \
    --platform macosx \
    --target-device mac \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "${asset_output_directory}/asset-info.plist"

codesign --force --sign - "${app_directory}"

echo "已生成 ${app_directory}"
