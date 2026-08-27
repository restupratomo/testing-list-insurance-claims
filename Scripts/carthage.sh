#!/bin/sh
#
# Bootstraps this project's Carthage dependencies (Texture, Alamofire,
# RxSwift, Quick, Nimble) as xcframeworks, matching what CI runs.
#
# By default this clears any existing Carthage cache, then tries to
# restore a prebuilt Carthage/Build/ from the shared Google Drive zip
# (fast). If that download is unavailable or incomplete, it falls back
# to a real 'carthage bootstrap' from source (slow).
#
# Usage:
#   Scripts/carthage.sh              # clear cache, restore from Drive, else build from source
#   Scripts/carthage.sh update       # re-resolve Cartfile.resolved, then build from source (no Drive restore)
#   Scripts/carthage.sh --no-cache   # skip the Drive restore, build from source
#
# Requires Carthage: https://github.com/Carthage/Carthage
# On Apple Silicon, --use-xcframeworks avoids the "same architectures" lipo
# failure that plain Carthage builds hit when device and simulator slices
# both target arm64.

set -euo pipefail

cd "$(dirname "$0")/.."

# Google Drive file id for the combined Carthage/Build xcframeworks zip.
# Share link: https://drive.google.com/file/d/1gFu46fi7yozBkKfS_imnmQqyTKOREhcE/view
CARTHAGE_CACHE_DRIVE_FILE_ID="1gFu46fi7yozBkKfS_imnmQqyTKOREhcE"

if ! command -v carthage >/dev/null 2>&1; then
    echo "error: carthage is not installed. Run 'brew install carthage'." >&2
    exit 1
fi

RAW_COMMAND="${1:-bootstrap}"
USE_CACHE=true
COMMAND="$RAW_COMMAND"

case "$RAW_COMMAND" in
    bootstrap)
        ;;
    update)
        USE_CACHE=false
        ;;
    --no-cache)
        USE_CACHE=false
        COMMAND=bootstrap
        ;;
    *)
        echo "usage: $0 [bootstrap|update|--no-cache]" >&2
        exit 1
        ;;
esac

echo "Removing existing Carthage cache..."
rm -rf Carthage/Build Carthage/Checkouts
rm -rf "${HOME}/Library/Caches/org.carthage.CarthageKit"

# Downloads and extracts the prebuilt xcframeworks zip from Google Drive
# into Carthage/Build. Returns non-zero (without exiting, thanks to `set -e`
# being suspended by the caller's `if`) if the restore didn't fully succeed,
# so the caller can fall back to a real build.
download_prebuilt_cache() {
    echo "Downloading prebuilt xcframeworks from Google Drive..."

    zip_path="$(mktemp -t carthage-build).zip"
    html_path="$(mktemp -t carthage-drive-page)"
    cookie_jar="$(mktemp -t carthage-cookie)"
    trap 'rm -f "$zip_path" "$html_path" "$cookie_jar"' RETURN

    # Large Google Drive files (>100MB-ish) serve an interstitial "can't
    # scan for viruses" confirmation page instead of the file directly. That
    # page's form posts to drive.usercontent.google.com with a per-request
    # uuid token, so scrape both the confirm value and uuid out of it and
    # replay them against that endpoint.
    curl -sL -c "$cookie_jar" \
        "https://drive.google.com/uc?export=download&id=${CARTHAGE_CACHE_DRIVE_FILE_ID}" \
        -o "$html_path"

    if grep -q 'uc-download-link\|drive.usercontent.google.com' "$html_path"; then
        confirm=$(grep -o 'name="confirm" value="[^"]*"' "$html_path" | head -n1 | sed -E 's/.*value="([^"]*)"/\1/')
        uuid=$(grep -o 'name="uuid" value="[^"]*"' "$html_path" | head -n1 | sed -E 's/.*value="([^"]*)"/\1/')
        download_url="https://drive.usercontent.google.com/download?id=${CARTHAGE_CACHE_DRIVE_FILE_ID}&export=download&confirm=${confirm:-t}&uuid=${uuid}"
    else
        # Small files download directly from the first request; html_path
        # already holds the file content in that case.
        cp "$html_path" "$zip_path"
        download_url=""
    fi

    if [ -n "$download_url" ] && ! curl -fL -b "$cookie_jar" "$download_url" -o "$zip_path"; then
        echo "warning: failed to download prebuilt Carthage cache; falling back to a full build." >&2
        return 1
    fi

    # A failed/blocked download often lands an HTML error page instead of a
    # zip; `unzip -t` catches that before we trust the contents.
    if ! unzip -tq "$zip_path" >/dev/null 2>&1; then
        echo "warning: downloaded file is not a valid zip; falling back to a full build." >&2
        return 1
    fi

    mkdir -p Carthage
    if ! unzip -q -o "$zip_path" -d Carthage; then
        echo "warning: failed to extract prebuilt Carthage cache; falling back to a full build." >&2
        return 1
    fi

    if [ ! -d Carthage/Build ] || [ -z "$(ls -A Carthage/Build 2>/dev/null)" ]; then
        echo "warning: prebuilt Carthage cache was empty; falling back to a full build." >&2
        return 1
    fi

    echo "Restored xcframeworks from cache:"
    ls Carthage/Build
    return 0
}

if [ "$USE_CACHE" = true ] && download_prebuilt_cache; then
    echo "Done. Frameworks are in Carthage/Build/ (restored from cache)."
    exit 0
fi

# Texture 3.2.0 has four chained-comparison expressions ('X < Y < Z') in its
# own source that trip Clang's -Wparentheses diagnostic. On the Clang shipped
# with recent Xcode that specific diagnostic is error-by-default regardless
# of GCC_TREAT_WARNINGS_AS_ERRORS, and Carthage has no CLI passthrough to
# override it at the compiler-flag level (an -xcconfig override doesn't work
# either: the project's own OTHER_CFLAGS is a literal array without
# $(inherited), so it fully shadows anything from a passed-in xcconfig).
# So checkout and build are split into two steps here, with a source patch
# in between: add explicit parens around the first comparison, which doesn't
# change behavior (< is already left-associative) but satisfies the
# diagnostic. This only touches the checkout, which Carthage/Build/ doesn't
# depend on afterward, and is re-applied on every run since the checkout is
# fresh each time.
patch_texture_chained_comparison() {
    file="Carthage/Checkouts/Texture/Source/TextExperiment/Component/ASTextLayout.mm"
    [ -f "$file" ] || return 0
    perl -pi -e 's/(fabs\([^)]+\) < fabs\([^)]+\)) < \(right \? prev : next\);/($1) < (right ? prev : next);/' "$file"
}

echo "Running 'carthage $COMMAND --platform iOS --use-xcframeworks --no-use-binaries --no-build'..."
carthage "$COMMAND" --platform iOS --use-xcframeworks --no-use-binaries --no-build

patch_texture_chained_comparison

echo "Running 'carthage build --platform iOS --use-xcframeworks --no-use-binaries'..."
carthage build --platform iOS --use-xcframeworks --no-use-binaries

echo "Done. Frameworks are in Carthage/Build/."
