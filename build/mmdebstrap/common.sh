#!/bin/sh

atlantis_die() {
    echo "$*" >&2
    exit 1
}

atlantis_require_command() {
    command -v "$1" >/dev/null 2>&1 || atlantis_die "$1 is required."
}

atlantis_command_available() {
    command -v "$1" >/dev/null 2>&1
}

atlantis_require_file() {
    [ -f "$1" ] || atlantis_die "Required file not found: $1"
}

atlantis_require_dir() {
    [ -d "$1" ] || atlantis_die "Required directory not found: $1"
}

atlantis_require_path() {
    [ -e "$1" ] || atlantis_die "Required path not found: $1"
}

atlantis_require_value() {
    name=$1
    value=$2

    [ -n "$value" ] || atlantis_die "$name must be set."
}

atlantis_path_from_repo() {
    path=${1:-}

    case "$path" in
        "")
            printf ''
            ;;
        /*)
            printf '%s' "$path"
            ;;
        *)
            printf '%s/%s' "$REPO_ROOT" "$path"
            ;;
    esac
}

atlantis_write_kv() {
    file_path=$1
    key=$2
    value=$3

    printf '%s=%s\n' "$key" "$value" >> "$file_path"
}

atlantis_write_shell_kv() {
    file_path=$1
    key=$2
    value=$3

    printf "%s='%s'\n" "$key" "$(atlantis_escape_squote "$value")" >> "$file_path"
}

atlantis_value_is_unresolved() {
    value=${1:-}

    case "$value" in
        "" | "UNRESOLVED" | "unresolved" | "PLACEHOLDER" | "placeholder" | "TODO" | "todo")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

atlantis_read_first_line() {
    file_path=$1
    line=''

    IFS= read -r line < "$file_path" || true
    printf '%s' "$line"
}

atlantis_value_from_env_file() {
    file_path=$1
    variable_name=$2

    sh -c '. "$1"; eval "printf %s \"\${$2-}\""' sh "$file_path" "$variable_name"
}

atlantis_escape_squote() {
    value=${1:-}
    printf "%s" "$value" | sed "s/'/'\\\\''/g"
}

atlantis_timestamp_utc() {
    if command -v date >/dev/null 2>&1; then
        date -u +"%Y-%m-%dT%H:%M:%SZ"
        return 0
    fi

    printf 'unknown-time'
}

atlantis_load_profile() {
    default_profile=$1

    PROFILE=$(atlantis_path_from_repo "${ATLANTIS_PROFILE:-$default_profile}")
    atlantis_require_file "$PROFILE"

    ATLANTIS_REPO_ROOT=$REPO_ROOT
    export ATLANTIS_REPO_ROOT

    # shellcheck disable=SC1090
    . "$PROFILE"

    PROFILE_NAME=${PROFILE_NAME:-${ATLANTIS_PROFILE_NAME:-development-bookworm-arm64}}
    PROFILE_KIND=${PROFILE_KIND:-${ATLANTIS_PROFILE_KIND:-generic}}
}
