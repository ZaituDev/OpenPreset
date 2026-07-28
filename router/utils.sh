#!/usr/bin/env sh
# utils.sh — generic helpers, no networking, no business logic
# POSIX sh. Avoids bashisms (no [[, no arrays, no ${var,,}) so it runs
# unmodified under dash, bash, ksh, busybox ash, and zsh's sh-emulation mode.

# Print an error to stderr and return 1.
# Never calls exit — router_engine.sh is sourced, so exit would kill the
# user's shell. Callers are responsible for propagating the return value.
die() {
    printf '%s\n' "✘ $*" >&2
    return 1
}

# Print a warning to stderr.
warn() {
    printf '%s\n' "⚠️  $*" >&2
}

# Print an informational line to stderr.
info() {
    printf '%s\n' "ℹ️  $*" >&2
}

# Show an animated spinner while a background job runs.
# Usage: spinner <pid> [label]
spinner() {
    _sp_pid="${1}"
    _sp_label="${2:-Working…}"
    _sp_frames='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'
    _sp_i=0

    while kill -0 "${_sp_pid}" 2>/dev/null; do
        _sp_i=$(( (_sp_i % 10) + 1 ))
        _sp_frame=$(printf '%s\n' ${_sp_frames} | sed -n "${_sp_i}p")
        printf '\r%s %s ' "${_sp_frame}" "${_sp_label}" >&2
        sleep 0.1
    done
    _sp_erase=$(( ${#_sp_label} + 4 ))
    printf '\r%*s\r' "${_sp_erase}" '' >&2
    unset _sp_pid _sp_label _sp_frames _sp_i _sp_frame _sp_erase
}

# Return a Unix timestamp (seconds since epoch).
timestamp() {
    date +%s
}

# Produce a slug safe for use in OpenRouter preset names.
# Lowercases input, replaces forward-slashes with hyphens, then collapses any
# remaining run of non-alphanumeric characters into a single hyphen and strips
# a trailing hyphen.
# Usage: sanitize_slug <string>
# Example: sanitize_slug "deepseek/deepseek-v4-flash"
#          → "deepseek-deepseek-v4-flash"
sanitize_slug() {
    printf '%s' "${1}" \
        | tr '[:upper:]' '[:lower:]' \
        | tr '/' '-' \
        | tr -cs 'a-z0-9-' '-' \
        | sed 's/-$//'
}

# Lowercase a string (portable replacement for zsh's ${var:l}).
to_lower() {
    printf '%s' "${1}" | tr '[:upper:]' '[:lower:]'
}

# Trim a string to N characters (portable replacement for zsh's ${str[1,N]}).
# Usage: truncate_str <string> <length>
truncate_str() {
    printf '%s' "${1}" | cut -c "1-${2:-16}"
}

# Return 0 if input is a positive integer (portable [[ =~ ^[0-9]+$ ]]).
is_int() {
    case "${1}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}
