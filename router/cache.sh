#!/usr/bin/env sh
# cache.sh — cache lifecycle management
# No UI, no preset logic, no networking (delegates to openrouter.sh).

# ── Predicates ───────────────────────────────────────────────────────────────

# Return 0 if the cache file and its timestamp file both exist.
cache_exists() {
    [ -f "${CACHE_FILE}" ] && [ -f "${CACHE_TIMESTAMP}" ]
}

# Print the age of the cache in seconds, or a large number if absent.
cache_age() {
    if [ ! -f "${CACHE_TIMESTAMP}" ]; then
        printf '%s\n' 999999
        return
    fi
    _stored=$(cat "${CACHE_TIMESTAMP}")
    printf '%s\n' $(( $(timestamp) - _stored ))
    unset _stored
}

# Return 0 if the cache exists and is younger than CACHE_TTL seconds.
cache_valid() {
    cache_exists || return 1
    [ "$(cache_age)" -lt "${CACHE_TTL}" ]
}

# ── I/O ──────────────────────────────────────────────────────────────────────

# Print the raw JSON content of the cache to stdout.
load_cache() {
    cat "${CACHE_FILE}"
}

# Write JSON (from stdin or first argument) to the cache.
save_cache() {
    mkdir -p "${CACHE_DIR}"
    if [ $# -gt 0 ]; then
        printf '%s' "${1}" > "${CACHE_FILE}"
    else
        cat > "${CACHE_FILE}"
    fi
    timestamp > "${CACHE_TIMESTAMP}"
}

# Force a fresh download and persist it.
# Delegates the actual HTTP call to download_models() from openrouter.sh.
refresh_cache() {
    info "Refreshing model cache…"
    _payload=$(download_models) || { die "Failed to download model list from OpenRouter."; unset _payload; return 1; }
    save_cache "${_payload}"
    unset _payload
}
