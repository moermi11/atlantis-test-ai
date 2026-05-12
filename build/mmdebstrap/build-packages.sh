#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$SCRIPT_DIR/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

INCLUDE_DEVICE_PACKAGE=0

if [ "${1:-}" = "--include-device" ]; then
    INCLUDE_DEVICE_PACKAGE=1
elif [ $# -gt 0 ]; then
    atlantis_die "Unknown argument: $1"
fi

sh "$SCRIPT_DIR/preflight.sh" package-build
atlantis_load_profile "$DEFAULT_PROFILE"

PACKAGE_ARTIFACT_DIR=$(atlantis_path_from_repo "${ATLANTIS_PACKAGE_ARTIFACT_DIR:-}")
atlantis_require_value "ATLANTIS_PACKAGE_ARTIFACT_DIR" "$PACKAGE_ARTIFACT_DIR"
mkdir -p "$PACKAGE_ARTIFACT_DIR"
find "$PACKAGE_ARTIFACT_DIR" -maxdepth 1 -type f -name '*.deb' -delete

build_one_package() {
    package_dir_rel=$1
    package_dir=$(atlantis_path_from_repo "$package_dir_rel")

    atlantis_require_dir "$package_dir"
    atlantis_require_file "$package_dir/debian/control"
    atlantis_require_file "$package_dir/debian/changelog"
    atlantis_require_file "$package_dir/debian/rules"

    package_name=$(dpkg-parsechangelog -l"$package_dir/debian/changelog" -SSource)
    package_version=$(dpkg-parsechangelog -l"$package_dir/debian/changelog" -SVersion)

    (
        cd "$package_dir"
        dpkg-buildpackage -us -uc -b
    )

    found_artifact=0
    for deb in "$package_dir"/../"${package_name}"_"${package_version}"_*.deb; do
        if [ -f "$deb" ]; then
            cp "$deb" "$PACKAGE_ARTIFACT_DIR"/
            found_artifact=1
        fi
    done

    if [ "$found_artifact" -ne 1 ]; then
        atlantis_die "Built package artifact not found for $package_name $package_version."
    fi

    echo "Built $package_name $package_version into $PACKAGE_ARTIFACT_DIR"
}

build_one_package "packages/atlantis-base"
build_one_package "packages/atlantis-shell"
build_one_package "packages/atlantis-branding"

if [ "$INCLUDE_DEVICE_PACKAGE" -eq 1 ]; then
    build_one_package "packages/atlantis-device-google-shiba"
fi

echo "Atlantis package artifacts written to $PACKAGE_ARTIFACT_DIR"
echo "Atlantis package build profile: $PROFILE_NAME ($PROFILE)"
