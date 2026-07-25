#!/usr/bin/env sh
# preset.sh — pure data transforms and local preset metadata I/O
# Nothing interactive. Nothing networked.

# ── Slug helpers ─────────────────────────────────────────────────────────────

# Produce a stable OpenRouter preset slug from a model id and preset name.
# Usage: preset_slug <model-id> <preset-name>
# Example: preset_slug "deepseek/deepseek-v4-flash" "Cheapest"
#          → "claude-deepseek-deepseek-v4-flash-cheapest"
preset_slug() {
    _model="${1:?preset_slug requires a model id}"
    _name="${2:?preset_slug requires a preset name}"
    sanitize_slug "${PRESET_PREFIX}-${_model}-${_name}"
    unset _model _name
}

# ── OpenRouter payload builders ──────────────────────────────────────────────

# Build a single provider entry for the preset's provider array.
# Usage: provider_payload <provider-name> [weight]
provider_payload() {
    _name="${1:?provider_payload requires a provider name}"
    _weight="${2:-1}"
    printf '{"provider":"%s","weight":%d}' "${_name}" "${_weight}"
    unset _name _weight
}

preset_payload() {
    _slug="${1:?preset_payload requires a slug}"
    _model="${2:?preset_payload requires a model id}"
    _providers="${3:?preset_payload requires a providers array}"

    _provider_order=$(printf '%s' "${_providers}" | jq '[.[].provider]')

    jq -nc \
       --arg model "${_model}" \
       --argjson order "${_provider_order}" '
    {
      model: $model,
      messages: [
        {
          role: "user",
          content: "router preset"
        }
      ],
      provider: {
        order: $order
      }
    }'

    unset _slug _model _providers _provider_order
}

# ── Local metadata file helpers ──────────────────────────────────────────────

# Return the path to the metadata file for a given model.
# Usage: preset_metadata_file <model-id>
preset_metadata_file() {
    _model="${1:?preset_metadata_file requires a model id}"
    _safe=$(printf '%s' "${_model}" | tr '/' '-')
    printf '%s\n' "${PRESETS_DIR}/${_safe}.json"
    unset _model _safe
}

# Load all presets for a model as a JSON array (prints to stdout).
# Returns an empty array if the file does not exist.
preset_load_all() {
    _model="${1:?preset_load_all requires a model id}"
    _file=$(preset_metadata_file "${_model}")
    if [ -f "${_file}" ]; then
        cat "${_file}"
    else
        printf '%s\n' '[]'
    fi
    unset _model _file
}

# Save a JSON array of presets for a model.
# Usage: preset_save_all <model-id> <json-array>
preset_save_all() {
    _psa_model="${1:?preset_save_all requires a model id}"
    _psa_json="${2:?preset_save_all requires a JSON array}"
    _psa_file=$(preset_metadata_file "${_psa_model}")
    mkdir -p "${PRESETS_DIR}"
    printf '%s' "${_psa_json}" > "${_psa_file}"
    unset _psa_model _psa_json _psa_file
}

# Append or update a single preset entry in the model's metadata file.
# Usage: preset_upsert <model-id> <slug> <name> <providers-json-array>
preset_upsert() {
    _pu_model="${1:?preset_upsert requires a model id}"
    _pu_slug="${2:?preset_upsert requires a slug}"
    _pu_name="${3:?preset_upsert requires a name}"
    _pu_providers="${4:?preset_upsert requires providers}"

    _pu_existing=$(preset_load_all "${_pu_model}")

    # Remove any entry with the same slug, then append the new one.
    _pu_updated=$(printf '%s' "${_pu_existing}" \
        | jq --arg slug "${_pu_slug}" 'map(select(.slug != $slug))')
    _pu_updated=$(printf '%s' "${_pu_updated}" \
        | jq --arg slug "${_pu_slug}" \
             --arg name "${_pu_name}" \
             --arg model "${_pu_model}" \
             --argjson providers "${_pu_providers}" \
             '. + [{"slug":$slug,"name":$name,"model":$model,"providers":$providers}]')

    preset_save_all "${_pu_model}" "${_pu_updated}"
    unset _pu_model _pu_slug _pu_name _pu_providers _pu_existing _pu_updated
}

# Remove a preset entry from the model's metadata file by slug.
# Usage: preset_remove <model-id> <slug>
preset_remove() {
    _pr_model="${1:?preset_remove requires a model id}"
    _pr_slug="${2:?preset_remove requires a slug}"
    _pr_existing=$(preset_load_all "${_pr_model}")
    _pr_updated=$(printf '%s' "${_pr_existing}" \
        | jq --arg slug "${_pr_slug}" 'map(select(.slug != $slug))')
    preset_save_all "${_pr_model}" "${_pr_updated}"
    unset _pr_model _pr_slug _pr_existing _pr_updated
}

# Rename a preset in the model's metadata file.
# Usage: preset_rename_local <model-id> <old-slug> <new-name> <new-slug>
preset_rename_local() {
    _prl_model="${1:?preset_rename_local requires a model id}"
    _prl_old_slug="${2:?preset_rename_local requires an old slug}"
    _prl_new_name="${3:?preset_rename_local requires a new name}"
    _prl_new_slug="${4:?preset_rename_local requires a new slug}"

    _prl_existing=$(preset_load_all "${_prl_model}")
    _prl_updated=$(printf '%s' "${_prl_existing}" | jq \
        --arg old_slug "${_prl_old_slug}" \
        --arg new_slug "${_prl_new_slug}" \
        --arg new_name "${_prl_new_name}" \
        'map(if .slug == $old_slug then .slug = $new_slug | .name = $new_name else . end)')
    preset_save_all "${_prl_model}" "${_prl_updated}"
    unset _prl_model _prl_old_slug _prl_new_name _prl_new_slug _prl_existing _prl_updated
}

# Build a providers JSON array string from an ordered list of provider names.
# Usage: providers_array_from_names <provider1> <provider2> …
providers_array_from_names() {
    _arr="["
    _first=1
    for _p in "$@"; do
        [ "${_first}" -eq 1 ] || _arr="${_arr},"
        _arr="${_arr}$(provider_payload "${_p}" 1)"
        _first=0
    done
    _arr="${_arr}]"
    printf '%s\n' "${_arr}"
    unset _arr _first _p
}
