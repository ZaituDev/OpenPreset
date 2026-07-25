#!/usr/bin/env sh
# openrouter.sh — OpenRouter REST API surface
# No jq parsing beyond decoding responses. No UI. No preset business logic.
# Authenticates with ANTHROPIC_AUTH_TOKEN.

# ── Internal helper ──────────────────────────────────────────────────────────

_get_or_token() {
    printf '%s' "${OPENROUTER_API_KEY:-${ANTHROPIC_AUTH_TOKEN:-}}"
}

_or_curl() {
    _token=$(_get_or_token)
    curl --silent --fail \
         --header "Authorization: Bearer ${_token}" \
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
    _de_model="${1:?download_endpoints requires a model id}"
    _or_curl "${OPENROUTER_API}/models/${_de_model}/endpoints"
    unset _de_model
}

# Validate that a model id exists in the OpenRouter catalogue.
# Returns 0 if found, 1 if not.
validate_model() {
    _vm_model="${1:?validate_model requires a model id}"
    _vm_response=$(download_endpoints "${_vm_model}") || { unset _vm_model _vm_response; return 1; }
    printf '%s' "${_vm_response}" | jq -e '.data | length > 0' > /dev/null 2>&1
    _vm_rc=$?
    unset _vm_model _vm_response
    return "${_vm_rc}"
}

create_or_update_preset() {
    _coup_slug="${1:?create_or_update_preset requires a slug}"
    _coup_payload="${2:?create_or_update_preset requires a JSON payload}"

    _or_curl --request POST \
             --data "${_coup_payload}" \
             "${OPENROUTER_API}/presets/${_coup_slug}/chat/completions" > /dev/null
    _coup_rc=$?
    unset _coup_slug _coup_payload
    return "${_coup_rc}"
}

# Delete a preset by slug.
# Usage: delete_preset <slug>
delete_preset() {
    _dp_slug="${1:?delete_preset requires a slug}"
    _or_curl --request DELETE "${OPENROUTER_API}/presets/${_dp_slug}"
    _dp_rc=$?
    unset _dp_slug
    return "${_dp_rc}"
}

# Verify API token is accepted by OpenRouter.
verify_api_key() {
    _token=$(_get_or_token)
    [ -n "${_token}" ] \
        || { warn "Neither OPENROUTER_API_KEY nor ANTHROPIC_AUTH_TOKEN is set."; return 1; }

    _vak_response=$(_or_curl "${OPENROUTER_API}/auth/key") \
        || { warn "API key verification request failed."; unset _vak_response _token; return 1; }

    printf '%s' "${_vak_response}" | grep -q '"data"' \
        || { warn "API key appears invalid."; unset _vak_response _token; return 1; }
    unset _vak_response _token
}
