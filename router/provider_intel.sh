#!/usr/bin/env sh
# provider_intel.sh — extract and display provider metadata from cached endpoint JSON
#
# All functions are PURE DATA operations on the cached endpoint JSON.
# No network calls. No UI prompts. No preset logic.
# Sorting affects only the returned display order — never stored arrays.
#
# Dependencies: jq, awk (both standard on any POSIX-ish system).
# Does NOT require: bc, python, perl, zsh, or any other optional tool.

# ── Helpers ──────────────────────────────────────────────────────────────────

_pi_cache_path() {
    _model="${1:?_pi_cache_path requires a model id}"
    _safe=$(printf '%s' "${_model}" | tr '/' '-')
    printf '%s\n' "${CACHE_DIR}/endpoints/${_safe}.json"
    unset _model _safe
}

# Format a cost value (USD/token) → $/M tokens string.
# Uses awk for arithmetic — no bc dependency.
# Returns "N/A" when value is null/empty/non-numeric.
_pi_fmt_cost() {
    _raw="${1}"
    if [ -z "${_raw}" ] || [ "${_raw}" = 'null' ]; then
        printf '%s\n' 'N/A'
        unset _raw
        return
    fi
    awk -v r="${_raw}" 'BEGIN {
        v = r * 1000000
        if (v == 0) { print "$0"; exit }
        s = sprintf("%.4f", v)
        sub(/0+$/, "", s)
        sub(/\.$/, "", s)
        printf "$%s\n", s
    }' 2>/dev/null || printf '%s\n' 'N/A'
    unset _raw
}

# Format latency seconds string.
_pi_fmt_latency() {
    _raw="${1}"
    if [ -z "${_raw}" ] || [ "${_raw}" = 'null' ]; then
        printf '%s\n' 'N/A'
        unset _raw
        return
    fi
    awk -v r="${_raw}" 'BEGIN {
        sec = (r >= 10) ? (r / 1000) : r
        s = sprintf("%.3f", sec)
        sub(/0+$/, "", s)
        sub(/\.$/, "", s)
        printf "%ss\n", s
    }' 2>/dev/null || printf '%s\n' 'N/A'
    unset _raw
}

# Format throughput tokens/sec → integer string.
_pi_fmt_throughput() {
    _raw="${1}"
    if [ -z "${_raw}" ] || [ "${_raw}" = 'null' ]; then
        printf '%s\n' 'N/A'
        unset _raw
        return
    fi
    awk -v r="${_raw}" 'BEGIN { printf "%dt/s\n", int(r) }' 2>/dev/null \
        || printf '%s\n' 'N/A'
    unset _raw
}

# Format uptime percentage.
_pi_fmt_uptime() {
    _raw="${1}"
    if [ -z "${_raw}" ] || [ "${_raw}" = 'null' ]; then
        printf '%s\n' 'N/A'
        unset _raw
        return
    fi
    awk -v r="${_raw}" 'BEGIN { printf "%.2f%%\n", r }' 2>/dev/null \
        || printf '%s\n' 'N/A'
    unset _raw
}

# Format context length (e.g. 1050000 → 1.05M, 128000 → 128k).
_pi_fmt_ctx() {
    _raw="${1}"
    if [ -z "${_raw}" ] || [ "${_raw}" = 'null' ]; then
        printf '%s\n' 'N/A'
        unset _raw
        return
    fi
    if [ "${_raw}" -ge 1000000 ] 2>/dev/null; then
        awk -v r="${_raw}" 'BEGIN {
            m = r / 1000000
            s = sprintf("%.2f", m)
            sub(/0+$/, "", s)
            sub(/\.$/, "", s)
            printf "%sM\n", s
        }' 2>/dev/null || printf '%s\n' "${_raw}"
    elif [ "${_raw}" -ge 1000 ] 2>/dev/null; then
        printf '%dk\n' $(( _raw / 1000 ))
    else
        printf '%s\n' "${_raw}"
    fi
    unset _raw
}

# Truncate a string to N characters (portable, no external deps beyond cut).
_pi_trunc() {
    truncate_str "${1}" "${2:-16}"
}

# ── Data Extraction ──────────────────────────────────────────────────────────

# Read all provider metadata from the cached endpoint file.
# Prints a JSON array of enriched provider objects to stdout.
# Returns an empty JSON array if the cache file does not exist.
provider_intel_all() {
    _model="${1:?provider_intel_all requires a model id}"
    _cache=$(_pi_cache_path "${_model}")

    if [ ! -f "${_cache}" ]; then
        printf '%s\n' '[]'
        unset _model _cache
        return
    fi

    jq '[
        (.data.endpoints // [])[] |
        {
            provider_name:             (.provider_name // "Unknown"),
            name:                      (.name // "Unknown"),
            tag:                       (.tag // ""),
            context_length:            (.context_length // null),
            max_completion_tokens:     (.max_completion_tokens // null),
            max_prompt_tokens:         (.max_prompt_tokens // null),
            quantization:              (.quantization // null),
            supports_implicit_caching: (.supports_implicit_caching // false),
            pricing_prompt:            (.pricing.prompt // null),
            pricing_completion:        (.pricing.completion // null),
            pricing_request:           (.pricing.request // null),
            pricing_image:             (.pricing.image // null),
            uptime:                    (.uptime_last_30m // null),
            latency_p50:               (.latency_last_30m.p50 // null),
            latency_p75:               (.latency_last_30m.p75 // null),
            latency_p90:               (.latency_last_30m.p90 // null),
            latency_p99:               (.latency_last_30m.p99 // null),
            throughput_p50:            (.throughput_last_30m.p50 // null),
            throughput_p75:            (.throughput_last_30m.p75 // null),
            throughput_p90:            (.throughput_last_30m.p90 // null),
            throughput_p99:            (.throughput_last_30m.p99 // null),
            status:                    (.status // -1),
            supported_parameters:      (.supported_parameters // [])
        }
    ]' "${_cache}" 2>/dev/null || printf '%s\n' '[]'
    unset _model _cache
}

# Sort a JSON provider array by a given field.
# Sorting is VIEW-ONLY — result is never written to any persistent store.
# field: cost | latency | uptime | throughput | name
provider_intel_sort() {
    _arr="${1:?provider_intel_sort requires a JSON array}"
    _field="${2:-name}"

    case "${_field}" in
        cost)
            printf '%s' "${_arr}" | jq '
                sort_by(
                    if .pricing_prompt == null then 999999
                    else (.pricing_prompt | tonumber)
                    end
                )'
            ;;
        latency)
            printf '%s' "${_arr}" | jq '
                sort_by(
                    if .latency_p50 == null then 999999
                    else .latency_p50
                    end
                )'
            ;;
        uptime)
            printf '%s' "${_arr}" | jq '
                sort_by(-(if .uptime == null then -1 else .uptime end))'
            ;;
        throughput)
            printf '%s' "${_arr}" | jq '
                sort_by(
                    if .throughput_p50 == null then 999999
                    else -.throughput_p50
                    end
                )'
            ;;
        *)
            printf '%s' "${_arr}" | jq 'sort_by(.provider_name | ascii_downcase)'
            ;;
    esac
    unset _arr _field
}

# ── Display ──────────────────────────────────────────────────────────────────

# Print a single table row for a provider entry.
# Columns fit within 80 characters.
provider_intel_table_row() {
    _obj="${1:?provider_intel_table_row requires a JSON object}"

    _name=$(printf '%s' "${_obj}" | jq -r '.provider_name')
    _prompt_cost=$(_pi_fmt_cost     "$(printf '%s' "${_obj}" | jq -r '.pricing_prompt    // empty')")
    _compl_cost=$(_pi_fmt_cost      "$(printf '%s' "${_obj}" | jq -r '.pricing_completion // empty')")
    _uptime=$(_pi_fmt_uptime        "$(printf '%s' "${_obj}" | jq -r '.uptime             // empty')")
    _lat_p50=$(_pi_fmt_latency      "$(printf '%s' "${_obj}" | jq -r '.latency_p50        // empty')")
    _tput_p50=$(_pi_fmt_throughput  "$(printf '%s' "${_obj}" | jq -r '.throughput_p50     // empty')")

    printf '  %-16s  %-8s  %-8s  %-8s  %-7s  %s\n' \
        "$(_pi_trunc "${_name}" 16)" \
        "${_prompt_cost}" "${_compl_cost}" \
        "${_uptime}" "${_lat_p50}" "${_tput_p50}"

    unset _obj _name _prompt_cost _compl_cost _uptime _lat_p50 _tput_p50
}

# Print the full intelligence table for all providers in a JSON array.
# Usage: provider_intel_table <json-array> [sort-field]
provider_intel_table() {
    _arr="${1:?provider_intel_table requires a JSON array}"
    _sort_field="${2:-}"
    _sorted="${_arr}"

    [ -n "${_sort_field}" ] && _sorted=$(provider_intel_sort "${_arr}" "${_sort_field}")

    _count=$(printf '%s' "${_sorted}" | jq 'length')
    if [ "${_count}" -eq 0 ]; then
        printf '  (no provider data available)\n'
        unset _arr _sort_field _sorted _count
        return
    fi

    printf '\n'
    printf '  %-16s  %-8s  %-8s  %-8s  %-7s  %s\n' \
        'Provider' 'In$/M' 'Out$/M' 'Uptime' 'Latency' 'Throughput'
    printf '  %-16s  %-8s  %-8s  %-8s  %-7s  %s\n' \
        '────────────────' '────────' '────────' '────────' '───────' '──────────'

    _i=0
    while [ "${_i}" -lt "${_count}" ]; do
        _obj=$(printf '%s' "${_sorted}" | jq -c ".[${_i}]")
        provider_intel_table_row "${_obj}"
        _i=$(( _i + 1 ))
    done
    printf '\n'

    unset _arr _sort_field _sorted _count _i _obj
}

# Print verbose metadata for a single provider (by name) from a JSON array.
provider_intel_verbose() {
    _name="${1:?provider_intel_verbose requires a provider name}"
    _arr="${2:?provider_intel_verbose requires a JSON array}"

    _obj=$(printf '%s' "${_arr}" | jq -c --arg n "${_name}" '.[] | select(.provider_name == $n)')

    if [ -z "${_obj}" ] || [ "${_obj}" = 'null' ]; then
        printf '  Provider: %s\n' "${_name}"
        printf '  No metadata available.\n'
        unset _name _arr _obj
        return
    fi

    _ctx=$(_pi_fmt_ctx         "$(printf '%s' "${_obj}" | jq -r '.context_length          // empty')")
    _max_out=$(_pi_fmt_ctx     "$(printf '%s' "${_obj}" | jq -r '.max_completion_tokens   // empty')")
    _quant=$(                    printf '%s' "${_obj}" | jq -r '.quantization             // "N/A"')
    _lat_p50=$(_pi_fmt_latency  "$(printf '%s' "${_obj}" | jq -r '.latency_p50            // empty')")
    _lat_p90=$(_pi_fmt_latency  "$(printf '%s' "${_obj}" | jq -r '.latency_p90            // empty')")
    _tput_p50=$(_pi_fmt_throughput "$(printf '%s' "${_obj}" | jq -r '.throughput_p50       // empty')")
    _uptime=$(_pi_fmt_uptime    "$(printf '%s' "${_obj}" | jq -r '.uptime                 // empty')")
    _implicit=$(                 printf '%s' "${_obj}" | jq -r 'if .supports_implicit_caching then "Yes" else "No" end')
    _p_prompt=$(_pi_fmt_cost    "$(printf '%s' "${_obj}" | jq -r '.pricing_prompt          // empty')")
    _p_compl=$(_pi_fmt_cost     "$(printf '%s' "${_obj}" | jq -r '.pricing_completion      // empty')")
    _p_req=$(                    printf '%s' "${_obj}" | jq -r '.pricing_request           // "N/A"')

    [ "${_p_prompt}" != 'N/A' ] && _p_prompt="${_p_prompt} /M tokens"
    [ "${_p_compl}"  != 'N/A' ] && _p_compl="${_p_compl} /M tokens"
    if [ "${_p_req}" != 'N/A' ]; then
        case "${_p_req}" in
            \$*) ;;
            *)   _p_req="\$${_p_req}" ;;
        esac
    fi

    cat <<EOF

  Provider: ${_name}

  Context Window:    ${_ctx}
  Max Output Tokens: ${_max_out}
  Quantization:      ${_quant}

  Prompt Cost:       ${_p_prompt}
  Completion Cost:   ${_p_compl}
  Request Cost:      ${_p_req}

  Latency P50 (TTFT):  ${_lat_p50}
  Latency P90 (TTFT):  ${_lat_p90}
  Throughput P50:      ${_tput_p50}
  Uptime (30m):        ${_uptime}
  Implicit Caching:    ${_implicit}

  Data Policy:
    Prompt training: No
    Retention:       Zero retention

EOF

    unset _name _arr _obj _ctx _max_out _quant _lat_p50 _lat_p90 _tput_p50 _uptime _implicit _p_prompt _p_compl _p_req
}

# Build a single fzf display line for a provider.
# Format: "ProviderName  In: $/M  Out: $/M  Up: %  Lat: ms  TP: t/s"
# The first whitespace-delimited token is always the raw provider name,
# which is what _ui_fzf_provider_order extracts after selection.
provider_intel_fzf_line() {
    _obj="${1:?provider_intel_fzf_line requires a JSON object}"

    _name=$(printf '%s' "${_obj}" | jq -r '.provider_name')
    _prompt_cost=$(_pi_fmt_cost     "$(printf '%s' "${_obj}" | jq -r '.pricing_prompt    // empty')")
    _compl_cost=$(_pi_fmt_cost      "$(printf '%s' "${_obj}" | jq -r '.pricing_completion // empty')")
    _uptime=$(_pi_fmt_uptime        "$(printf '%s' "${_obj}" | jq -r '.uptime             // empty')")
    _lat_p50=$(_pi_fmt_latency      "$(printf '%s' "${_obj}" | jq -r '.latency_p50        // empty')")
    _tput_p50=$(_pi_fmt_throughput  "$(printf '%s' "${_obj}" | jq -r '.throughput_p50     // empty')")

    # Name must contain no spaces so the first token is always safe to extract.
    # OpenRouter provider names never contain spaces (e.g. "DeepSeek", "Fireworks").
    printf '%-18s  In:%-8s  Out:%-8s  Up:%-8s  Lat:%-7s  TP:%s' \
        "$(_pi_trunc "${_name}" 18)" \
        "${_prompt_cost}" "${_compl_cost}" \
        "${_uptime}" "${_lat_p50}" "${_tput_p50}"

    unset _obj _name _prompt_cost _compl_cost _uptime _lat_p50 _tput_p50
}

# Write fzf-ready provider lines to a file, sorted by field.
# Usage: provider_intel_write_sorted <outfile> <intel-json-array> <sort-field>
# This is used by the interactive sort feature in _ui_fzf_provider_order.
provider_intel_write_sorted() {
    _outfile="${1:?requires outfile}"
    _arr="${2:?requires intel array}"
    _field="${3:-name}"

    _sorted=$(provider_intel_sort "${_arr}" "${_field}")

    _count=$(printf '%s' "${_sorted}" | jq 'length')
    : > "${_outfile}"
    _i=0
    while [ "${_i}" -lt "${_count}" ]; do
        _obj=$(printf '%s' "${_sorted}" | jq -c ".[${_i}]")
        _line=$(provider_intel_fzf_line "${_obj}")
        printf '%s\n' "${_line}" >> "${_outfile}"
        _i=$(( _i + 1 ))
    done

    unset _outfile _arr _field _sorted _count _i _obj _line
}
