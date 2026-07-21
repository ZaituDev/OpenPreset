#!/usr/bin/env sh
# openrouter.sh — OpenRouter REST API surface
# No jq parsing beyond decoding responses. No UI. No preset business logic.
# Authenticates with ANTHROPIC_AUTH_TOKEN.

# ── Internal helper ──────────────────────────────────────────────────────────

_or_curl() {
    curl --silent --fail \
         --header "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" \
         --header "Content-Type: application/json" \
         "$@"
}

# ── Public functions ──────────────────────────────────────────────────────────

# Download the full OpenRouter model catalogue.
download_models() {
    _or_curl "${OPENROUTER_API}/models"
}

# Download provider endpoint details for a specific model slug.
# Usage: download_endpoints <model-id>
download_endpoints() {
    _model="${1:?download_endpoints requires a model id}"
    _or_curl "${OPENROUTER_API}/models/${_model}/endpoints"
    unset _model
}

# Validate that a model id exists in the OpenRouter catalogue.
# Returns 0 if found, 1 if not.
validate_model() {
    _model="${1:?validate_model requires a model id}"
    _response=$(download_endpoints "${_model}") || { unset _model _response; return 1; }
    printf '%s' "${_response}" | jq -e '.data | length > 0' > /dev/null 2>&1
    _rc=$?
    unset _model _response
    return "${_rc}"
}

create_or_update_preset() {
    _slug="${1:?create_or_update_preset requires a slug}"
    _payload="${2:?create_or_update_preset requires a JSON payload}"

    _or_curl --request POST \
             --data "${_payload}" \
             "${OPENROUTER_API}/presets/${_slug}/chat/completions" > /dev/null
    _rc=$?
    unset _slug _payload
    return "${_rc}"
}

# Delete a preset by slug.
# Usage: delete_preset <slug>
delete_preset() {
    _slug="${1:?delete_preset requires a slug}"
    _or_curl --request DELETE "${OPENROUTER_API}/presets/${_slug}"
    _rc=$?
    unset _slug
    return "${_rc}"
}

# Verify ANTHROPIC_AUTH_TOKEN is accepted by OpenRouter.
verify_api_key() {
    [ -n "${ANTHROPIC_AUTH_TOKEN}" ] \
        || { warn "ANTHROPIC_AUTH_TOKEN is not set."; return 1; }

    _response=$(_or_curl "${OPENROUTER_API}/auth/key") \
        || { warn "API key verification request failed."; unset _response; return 1; }

    printf '%s' "${_response}" | grep -q '"data"' \
        || { warn "API key appears invalid."; unset _response; return 1; }
    unset _response
}
