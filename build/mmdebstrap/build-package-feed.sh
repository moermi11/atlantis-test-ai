#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$SCRIPT_DIR/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$SCRIPT_DIR/preflight.sh" package-feed
atlantis_load_profile "$DEFAULT_PROFILE"

PROFILE_NAME=${PROFILE_NAME:-${ATLANTIS_PROFILE_NAME:-development-bookworm-arm64}}
PACKAGE_ARTIFACT_DIR=${PACKAGE_ARTIFACT_DIR:-"$(atlantis_path_from_repo "${ATLANTIS_PACKAGE_ARTIFACT_DIR:-}")"}
REPO_DIR=${REPO_DIR:-"$(atlantis_path_from_repo "${ATLANTIS_REPO_DIR:-out/repo}")"}

mkdir -p "$REPO_DIR"
find "$REPO_DIR" -maxdepth 1 -type f \( -name '*.deb' -o -name 'Packages' -o -name 'Packages.gz' \) -delete

found_debs=0
for deb in "$PACKAGE_ARTIFACT_DIR"/*.deb; do
    if [ -f "$deb" ]; then
        cp "$deb" "$REPO_DIR"/
        found_debs=1
    fi
done

if [ "$found_debs" -ne 1 ]; then
    echo "No built Atlantis .deb packages found under $PACKAGE_ARTIFACT_DIR." >&2
    echo "Build packages first with sh ./build/mmdebstrap/build-packages.sh before generating the feed." >&2
    exit 1
fi

(
    cd "$REPO_DIR"
    dpkg-scanpackages --multiversion . /dev/null > Packages
    gzip -fk Packages
)

echo "Local Atlantis package feed written to $REPO_DIR"
echo "Atlantis package feed profile: $PROFILE_NAME ($PROFILE)"
