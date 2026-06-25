#!/bin/bash
# Updates the macOS app marketing version in one place.
# Usage: ./bump-version.sh --patch|--minor|--major

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

usage() {
  echo "Usage: $0 --patch|--minor|--major"
  echo "Examples:"
  echo "  $0 --patch    (1.0.0 -> 1.0.1)"
  echo "  $0 --minor    (1.0.0 -> 1.1.0)"
  echo "  $0 --major    (1.0.0 -> 2.0.0)"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

BUMP_TYPE="$1"
if [[ "$BUMP_TYPE" != "--patch" && "$BUMP_TYPE" != "--minor" && "$BUMP_TYPE" != "--major" ]]; then
  echo "Error: First argument must be --patch, --minor, or --major"
  usage
  exit 1
fi

CONFIG_FILE="Pipetka/Configs/AppInfo.xcconfig"

CURRENT_VERSION=$(sed -n -E 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+){1,2})[[:space:]]*$/\1/p' "$CONFIG_FILE" | head -n 1)

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: Could not parse MARKETING_VERSION from $CONFIG_FILE"
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
PATCH="${PATCH:-0}"

case "$BUMP_TYPE" in
  --patch)
    PATCH=$((PATCH + 1))
    ;;
  --minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  --major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "Bumping version from $CURRENT_VERSION to $NEW_VERSION (using $BUMP_TYPE)..."

sed -i '' -E "s/^([[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*).*/\1$NEW_VERSION/" "$CONFIG_FILE"

echo "Updated $CONFIG_FILE: $CURRENT_VERSION -> $NEW_VERSION"
echo ""
echo "Version bump complete."
echo "Next: git add $CONFIG_FILE bump-version.sh && git commit -m 'Bump version to $NEW_VERSION'"
