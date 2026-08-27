#!/bin/sh
#
# Bootstraps this project's Carthage dependencies (Texture, Alamofire,
# RxSwift, Quick, Nimble) as xcframeworks, matching what CI runs.
#
# Usage:
#   Scripts/carthage.sh            # bootstrap (checkout + build) from Cartfile.resolved
#   Scripts/carthage.sh update     # re-resolve Cartfile.resolved, then checkout + build
#
# Requires Carthage: https://github.com/Carthage/Carthage
# On Apple Silicon, --use-xcframeworks avoids the "same architectures" lipo
# failure that plain Carthage builds hit when device and simulator slices
# both target arm64.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v carthage >/dev/null 2>&1; then
    echo "error: carthage is not installed. Run 'brew install carthage'." >&2
    exit 1
fi

COMMAND="${1:-bootstrap}"

case "$COMMAND" in
    bootstrap|update)
        ;;
    *)
        echo "usage: $0 [bootstrap|update]" >&2
        exit 1
        ;;
esac

echo "Running 'carthage $COMMAND --platform iOS --use-xcframeworks --no-use-binaries'..."
carthage "$COMMAND" --platform iOS --use-xcframeworks --no-use-binaries

echo "Done. Frameworks are in Carthage/Build/."
