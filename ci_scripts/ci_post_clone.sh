#!/bin/sh

set -e

# Xcode Cloud exposes the checkout here; local runs can execute from repo root.
if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
	cd "$CI_PRIMARY_REPOSITORY_PATH"
fi

CONFIG_FILE="Pipetka/Configs/AppInfo.xcconfig"

if [ ! -f "$CONFIG_FILE" ]; then
	echo "[ci_post_clone] ERROR: Missing $CONFIG_FILE"
	exit 1
fi

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
	echo "[ci_post_clone] CI_BUILD_NUMBER is not set; leaving CURRENT_PROJECT_VERSION unchanged"
	exit 0
fi

case "$CI_BUILD_NUMBER" in
	*[!0-9]*|"")
		echo "[ci_post_clone] ERROR: CI_BUILD_NUMBER must be numeric, got '$CI_BUILD_NUMBER'"
		exit 1
		;;
esac

configured_build_number=$(sed -n -E 's/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=[[:space:]]*([0-9]+)[[:space:]]*$/\1/p' "$CONFIG_FILE" | head -n 1)
if [ -n "$configured_build_number" ]; then
	case "$configured_build_number" in
		*[!0-9]*)
			echo "[ci_post_clone] ERROR: CURRENT_PROJECT_VERSION must be numeric, got '$configured_build_number'"
			exit 1
			;;
	esac
else
	configured_build_number=0
fi

build_number="$CI_BUILD_NUMBER"
if [ "$configured_build_number" -gt "$build_number" ]; then
	build_number="$configured_build_number"
fi

tmp_file="$CONFIG_FILE.tmp"
awk -v build_number="$build_number" '
BEGIN { updated = 0 }
/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/ {
	print "CURRENT_PROJECT_VERSION = " build_number
	updated = 1
	next
}
{ print }
END {
	if (!updated) {
		print "CURRENT_PROJECT_VERSION = " build_number
	}
}
' "$CONFIG_FILE" > "$tmp_file"
mv "$tmp_file" "$CONFIG_FILE"

version=$(sed -n -E 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$CONFIG_FILE" | head -n 1)
echo "[ci_post_clone] Version ${version:-unknown}, build $build_number (CI_BUILD_NUMBER=$CI_BUILD_NUMBER, minimum=$configured_build_number)"
