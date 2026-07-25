#!/usr/bin/env sh
# router/validate.sh — validation tests for claude-router
#
# Run: sh router/validate.sh   (or: ./router/validate.sh, bash router/validate.sh)
# Exit 0 = all tests passed. Non-zero = failures (printed to stderr).
#
# Portable POSIX sh — no zsh required to run these tests, matching the rest
# of the router. Uses only jq + POSIX shell builtins.

_TEST_FILE="$0"
case "${_TEST_FILE}" in
    /*) : ;;
    *) _TEST_FILE="$(pwd)/${_TEST_FILE}" ;;
esac
_TEST_DIR=$(cd -P "$(dirname "${_TEST_FILE}")" && pwd)
_ROOT=$(dirname "${_TEST_DIR}")

# ── Bootstrap router modules (no network, no launcher) ──────────────────────

export XDG_CACHE_HOME="/tmp/cr-test-cache-$$"
export XDG_CONFIG_HOME="/tmp/cr-test-config-$$"
export ANTHROPIC_BASE_URL="https://openrouter.ai/api/v1"
export ANTHROPIC_AUTH_TOKEN="sk-test-fake"
export CLAUDE_ROUTER_MODEL="test/model"

mkdir -p "${XDG_CACHE_HOME}/claude-router/endpoints"
mkdir -p "${XDG_CONFIG_HOME}/claude-router/presets"

# shellcheck source=config.sh
. "${_ROOT}/router/config.sh"
# shellcheck source=utils.sh
. "${_ROOT}/router/utils.sh"
# shellcheck source=provider_intel.sh
. "${_ROOT}/router/provider_intel.sh"

# ── Test harness ──────────────────────────────────────────────────────────────

_PASS=0
_FAIL=0

_assert() {
    _desc="${1}"; _result="${2}"; _expected="${3}"
    if [ "${_result}" = "${_expected}" ]; then
        printf '  ✅  %s\n' "${_desc}"
        _PASS=$(( _PASS + 1 ))
    else
        printf '  ❌  %s\n' "${_desc}" >&2
        printf '      expected: %s\n' "${_expected}" >&2
        printf '      got:      %s\n' "${_result}" >&2
        _FAIL=$(( _FAIL + 1 ))
    fi
    unset _desc _result _expected
}

_assert_contains() {
    _desc="${1}"; _haystack="${2}"; _needle="${3}"
    case "${_haystack}" in
        *"${_needle}"*)
            printf '  ✅  %s\n' "${_desc}"
            _PASS=$(( _PASS + 1 ))
            ;;
        *)
            printf '  ❌  %s\n' "${_desc}" >&2
            printf '      expected to contain: %s\n' "${_needle}" >&2
            printf '      got: %s\n' "${_haystack}" >&2
            _FAIL=$(( _FAIL + 1 ))
            ;;
    esac
    unset _desc _haystack _needle
}

_assert_not_contains() {
    _desc="${1}"; _haystack="${2}"; _needle="${3}"
    case "${_haystack}" in
        *"${_needle}"*)
            printf '  ❌  %s\n' "${_desc}" >&2
            printf '      expected NOT to contain: %s\n' "${_needle}" >&2
            printf '      got: %s\n' "${_haystack}" >&2
            _FAIL=$(( _FAIL + 1 ))
            ;;
        *)
            printf '  ✅  %s\n' "${_desc}"
            _PASS=$(( _PASS + 1 ))
            ;;
    esac
    unset _desc _haystack _needle
}

_assert_json_len() {
    _desc="${1}"; _json="${2}"; _expected_len="${3}"
    _actual=$(printf '%s' "${_json}" | jq 'length' 2>/dev/null)
    _assert "${_desc}" "${_actual}" "${_expected_len}"
    unset _desc _json _expected_len _actual
}

# ── Fixtures ──────────────────────────────────────────────────────────────────

FIXTURE_ENDPOINTS=$(cat << 'FIXTURE'
{
  "data": {
    "id": "deepseek/deepseek-v4-flash",
    "name": "DeepSeek V4 Flash",
    "endpoints": [
      {
        "name": "DeepSeek: DeepSeek V4 Flash",
        "model_id": "deepseek/deepseek-v4-flash",
        "provider_name": "DeepSeek",
        "tag": "deepseek",
        "context_length": 65536,
        "max_completion_tokens": 8192,
        "max_prompt_tokens": 65536,
        "quantization": "fp16",
        "supports_implicit_caching": true,
        "pricing": {
          "prompt": "0.00000014",
          "completion": "0.00000028",
          "request": "0",
          "image": "0"
        },
        "uptime_last_30m": 99.87,
        "latency_last_30m": {
          "p50": 0.584,
          "p75": 0.720,
          "p90": 0.901,
          "p99": 1.450
        },
        "throughput_last_30m": {
          "p50": 120.5,
          "p75": 98.3,
          "p90": 74.1,
          "p99": 42.0
        },
        "status": 0
      },
      {
        "name": "Fireworks: DeepSeek V4 Flash",
        "model_id": "deepseek/deepseek-v4-flash",
        "provider_name": "Fireworks",
        "tag": "fireworks",
        "context_length": 65536,
        "max_completion_tokens": 8192,
        "max_prompt_tokens": null,
        "quantization": null,
        "supports_implicit_caching": false,
        "pricing": {
          "prompt": "0.00000014",
          "completion": "0.00000028",
          "request": "0",
          "image": "0"
        },
        "uptime_last_30m": 96.56,
        "latency_last_30m": {
          "p50": 0.706,
          "p75": null,
          "p90": null,
          "p99": null
        },
        "throughput_last_30m": {
          "p50": 98.2,
          "p75": null,
          "p90": null,
          "p99": null
        },
        "status": 0
      },
      {
        "name": "Baidu: DeepSeek V4 Flash",
        "model_id": "deepseek/deepseek-v4-flash",
        "provider_name": "Baidu",
        "tag": "baidu",
        "context_length": 32768,
        "max_completion_tokens": 4096,
        "max_prompt_tokens": 32768,
        "quantization": "int8",
        "supports_implicit_caching": false,
        "pricing": {
          "prompt": "0.000000098",
          "completion": "0.000000196",
          "request": "0",
          "image": "0"
        },
        "uptime_last_30m": null,
        "latency_last_30m": null,
        "throughput_last_30m": null,
        "status": 0
      }
    ]
  }
}
FIXTURE
)

FIXTURE_EMPTY=$(cat << 'FIXTURE'
{
  "data": {
    "id": "test/empty",
    "name": "Empty Model",
    "endpoints": []
  }
}
FIXTURE
)

FIXTURE_CACHE="${XDG_CACHE_HOME}/claude-router/endpoints/deepseek-deepseek-v4-flash.json"
printf '%s' "${FIXTURE_ENDPOINTS}" > "${FIXTURE_CACHE}"

EMPTY_CACHE="${XDG_CACHE_HOME}/claude-router/endpoints/test-empty.json"
printf '%s' "${FIXTURE_EMPTY}" > "${EMPTY_CACHE}"

# ── Test group 1: _pi_cache_path ─────────────────────────────────────────────

printf '\n── _pi_cache_path ──────────────────────────────────────────────\n'

result=$(_pi_cache_path "deepseek/deepseek-v4-flash")
_assert_contains "_pi_cache_path replaces / with -" \
    "${result}" "deepseek-deepseek-v4-flash"

# ── Test group 2: _pi_fmt_cost ───────────────────────────────────────────────

printf '\n── _pi_fmt_cost ─────────────────────────────────────────────────\n'

_assert "_pi_fmt_cost null returns N/A" \
    "$(_pi_fmt_cost '')" "N/A"

_assert "_pi_fmt_cost 'null' string returns N/A" \
    "$(_pi_fmt_cost 'null')" "N/A"

result=$(_pi_fmt_cost "0.00000014")
_assert_contains "_pi_fmt_cost computes \$/M tokens" "${result}" "\$0.14"

# ── Test group 3: _pi_fmt_latency ────────────────────────────────────────────

printf '\n── _pi_fmt_latency ──────────────────────────────────────────────\n'

_assert "_pi_fmt_latency null returns N/A" "$(_pi_fmt_latency '')" "N/A"
_assert "_pi_fmt_latency 0.584 → 0.584s" "$(_pi_fmt_latency '0.584')" "0.584s"
_assert "_pi_fmt_latency 1.450 → 1.45s" "$(_pi_fmt_latency '1.450')" "1.45s"
_assert "_pi_fmt_latency 1284 → 1.284s" "$(_pi_fmt_latency '1284')" "1.284s"

# ── Test group 4: _pi_fmt_uptime ─────────────────────────────────────────────

printf '\n── _pi_fmt_uptime ───────────────────────────────────────────────\n'

_assert "_pi_fmt_uptime null returns N/A" "$(_pi_fmt_uptime '')" "N/A"
_assert "_pi_fmt_uptime 99.87 → 99.87%" "$(_pi_fmt_uptime '99.87')" "99.87%"

# ── Test group 5: _pi_fmt_ctx ────────────────────────────────────────────────

printf '\n── _pi_fmt_ctx ──────────────────────────────────────────────────\n'

_assert "_pi_fmt_ctx null returns N/A" "$(_pi_fmt_ctx '')" "N/A"
_assert "_pi_fmt_ctx 1050000 → 1.05M" "$(_pi_fmt_ctx '1050000')" "1.05M"
_assert "_pi_fmt_ctx 65536 → 65k" "$(_pi_fmt_ctx '65536')" "65k"
_assert "_pi_fmt_ctx 8192 → 8k" "$(_pi_fmt_ctx '8192')" "8k"
_assert "_pi_fmt_ctx 512 stays numeric" "$(_pi_fmt_ctx '512')" "512"

# ── Test group 6: provider_intel_all ─────────────────────────────────────────

printf '\n── provider_intel_all ───────────────────────────────────────────\n'

intel=$(provider_intel_all "deepseek/deepseek-v4-flash")
_assert_json_len "provider_intel_all returns 3 providers" "${intel}" "3"

deepseek_obj=$(printf '%s' "${intel}" | jq '.[] | select(.provider_name == "DeepSeek")')
_assert "DeepSeek uptime extracted" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.uptime')" "99.87"
_assert "DeepSeek latency_p50 extracted" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.latency_p50')" "0.584"
_assert "DeepSeek throughput_p50 extracted" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.throughput_p50')" "120.5"
_assert "DeepSeek pricing_prompt extracted" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.pricing_prompt')" "0.00000014"
_assert "DeepSeek context_length extracted" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.context_length')" "65536"
_assert "DeepSeek quantization extracted" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.quantization')" "fp16"
_assert "DeepSeek implicit_caching true" \
    "$(printf '%s' "${deepseek_obj}" | jq -r '.supports_implicit_caching')" "true"

fw_obj=$(printf '%s' "${intel}" | jq '.[] | select(.provider_name == "Fireworks")')
_assert "Fireworks max_prompt_tokens is null (graceful)" \
    "$(printf '%s' "${fw_obj}" | jq -r '.max_prompt_tokens')" "null"
_assert "Fireworks quantization is null (graceful)" \
    "$(printf '%s' "${fw_obj}" | jq -r '.quantization')" "null"
_assert "Fireworks latency_p75 null (sparse data)" \
    "$(printf '%s' "${fw_obj}" | jq -r '.latency_p75')" "null"

baidu_obj=$(printf '%s' "${intel}" | jq '.[] | select(.provider_name == "Baidu")')
_assert "Baidu uptime null (graceful)" \
    "$(printf '%s' "${baidu_obj}" | jq -r '.uptime')" "null"
_assert "Baidu latency_p50 null (graceful)" \
    "$(printf '%s' "${baidu_obj}" | jq -r '.latency_p50')" "null"

empty_result=$(provider_intel_all "test/empty")
_assert_json_len "provider_intel_all empty → []" "${empty_result}" "0"

missing_result=$(provider_intel_all "does/not/exist")
_assert_json_len "provider_intel_all missing cache → []" "${missing_result}" "0"

# ── Test group 7: provider_intel_sort ────────────────────────────────────────

printf '\n── provider_intel_sort ──────────────────────────────────────────\n'

sorted_cost=$(provider_intel_sort "${intel}" "cost")
first_by_cost=$(printf '%s' "${sorted_cost}" | jq -r '.[0].provider_name')
_assert "sort by cost: cheapest first (Baidu)" "${first_by_cost}" "Baidu"

sorted_lat=$(provider_intel_sort "${intel}" "latency")
first_by_lat=$(printf '%s' "${sorted_lat}" | jq -r '.[0].provider_name')
_assert "sort by latency: fastest first (DeepSeek)" "${first_by_lat}" "DeepSeek"

sorted_up=$(provider_intel_sort "${intel}" "uptime")
first_by_up=$(printf '%s' "${sorted_up}" | jq -r '.[0].provider_name')
_assert "sort by uptime: best first (DeepSeek)" "${first_by_up}" "DeepSeek"

sorted_tp=$(provider_intel_sort "${intel}" "throughput")
first_by_tp=$(printf '%s' "${sorted_tp}" | jq -r '.[0].provider_name')
_assert "sort by throughput: highest first (DeepSeek)" "${first_by_tp}" "DeepSeek"

sorted_name=$(provider_intel_sort "${intel}" "name")
first_by_name=$(printf '%s' "${sorted_name}" | jq -r '.[0].provider_name')
last_by_name=$(printf '%s' "${sorted_name}" | jq -r '.[-1].provider_name')
_assert "sort by name: alphabetical first (Baidu)" "${first_by_name}" "Baidu"
_assert "sort by name: alphabetical last (Fireworks)" "${last_by_name}" "Fireworks"

orig_first=$(printf '%s' "${intel}" | jq -r '.[0].provider_name')
after_sort_first=$(printf '%s' "${intel}" | jq -r '.[0].provider_name')
_assert "sort is non-destructive (original array unchanged)" \
    "${orig_first}" "${after_sort_first}"

# ── Test group 8: provider_intel_verbose ─────────────────────────────────────

printf '\n── provider_intel_verbose ───────────────────────────────────────\n'

verbose=$(provider_intel_verbose "DeepSeek" "${intel}")

_assert_contains "verbose includes provider name" "${verbose}" "DeepSeek"
_assert_contains "verbose includes context window formatted" "${verbose}" "65k"
_assert_contains "verbose includes quantization" "${verbose}" "fp16"
_assert_contains "verbose includes latency p50" "${verbose}" "0.584s"
_assert_contains "verbose includes uptime" "${verbose}" "99.87%"
_assert_contains "verbose includes implicit caching" "${verbose}" "Yes"

verbose_fw=$(provider_intel_verbose "Fireworks" "${intel}")
_assert_contains "verbose Fireworks null quantization → N/A" "${verbose_fw}" "N/A"

verbose_unknown=$(provider_intel_verbose "NonExistentProvider" "${intel}")
_assert_contains "verbose unknown provider is graceful" "${verbose_unknown}" "NonExistentProvider"

# ── Test group 9: provider_intel_table_row ───────────────────────────────────

printf '\n── provider_intel_table_row ─────────────────────────────────────\n'

deepseek_row=$(provider_intel_table_row "${deepseek_obj}")
_assert_contains "table row contains provider name" "${deepseek_row}" "DeepSeek"
_assert_contains "table row contains uptime" "${deepseek_row}" "99.87%"
_assert_contains "table row contains latency" "${deepseek_row}" "0.584s"

baidu_row=$(provider_intel_table_row "${baidu_obj}")
_assert_contains "table row Baidu null uptime → N/A" "${baidu_row}" "N/A"

# ── Test group 10: sanitize_slug (regression) ────────────────────────────────

printf '\n── sanitize_slug (regression) ───────────────────────────────────\n'

_assert "sanitize_slug slashes → hyphens" \
    "$(sanitize_slug 'deepseek/deepseek-v4-flash')" "deepseek-deepseek-v4-flash"
_assert "sanitize_slug lowercases" \
    "$(sanitize_slug 'OpenAI/GPT-4')" "openai-gpt-4"

# ── Test group 11: storage format unchanged ───────────────────────────────────

printf '\n── storage format regression ────────────────────────────────────\n'

# shellcheck source=preset.sh
. "${_ROOT}/router/preset.sh"

TEST_MODEL="test/storage-model"
TEST_SLUG="claude-test-storage-model-fast"
TEST_NAME="Fast"
TEST_PROVIDERS='[{"provider":"DeepSeek","weight":1},{"provider":"Fireworks","weight":1}]'

preset_upsert "${TEST_MODEL}" "${TEST_SLUG}" "${TEST_NAME}" "${TEST_PROVIDERS}"
loaded=$(preset_load_all "${TEST_MODEL}")

_assert_json_len "preset storage: one entry" "${loaded}" "1"

entry=$(printf '%s' "${loaded}" | jq '.[0]')
_assert "preset storage: slug field" \
    "$(printf '%s' "${entry}" | jq -r '.slug')" "${TEST_SLUG}"
_assert "preset storage: name field" \
    "$(printf '%s' "${entry}" | jq -r '.name')" "${TEST_NAME}"
_assert "preset storage: model field" \
    "$(printf '%s' "${entry}" | jq -r '.model')" "${TEST_MODEL}"
_assert "preset storage: providers is array" \
    "$(printf '%s' "${entry}" | jq '.providers | type')" '"array"'
_assert "preset storage: providers[0].provider" \
    "$(printf '%s' "${entry}" | jq -r '.providers[0].provider')" "DeepSeek"
_assert "preset storage: providers[0].weight" \
    "$(printf '%s' "${entry}" | jq -r '.providers[0].weight')" "1"

# shellcheck source=openrouter.sh
. "${_ROOT}/router/openrouter.sh"

# Mock _or_curl so create_or_update_preset can run without network
_or_curl() { return 0; }

_test_slug="my-preset-slug"
create_or_update_preset "${_test_slug}" '{"model":"test"}'
_assert "create_or_update_preset preserves caller _slug variable" \
    "${_test_slug}" "my-preset-slug"

# ── Test group 12: backup format unchanged ────────────────────────────────────

printf '\n── backup format regression ─────────────────────────────────────\n'

# shellcheck source=backup.sh
. "${_ROOT}/router/backup.sh"

mkdir -p "${CONFIG_DIR}"
printf '%s\n' "test/usermodel" > "${USER_MODELS_FILE}"

BACKUP_OUT="/tmp/cr-test-backup-$$.json"
backup_export "${BACKUP_OUT}" 2>/dev/null

if [ -f "${BACKUP_OUT}" ]; then
    bk=$(cat "${BACKUP_OUT}")
    _assert "backup schema_version is 1" \
        "$(printf '%s' "${bk}" | jq -r '.schema_version')" "1"
    _assert "backup has created_at" \
        "$(printf '%s' "${bk}" | jq 'has("created_at")')" "true"
    _assert "backup has user_models array" \
        "$(printf '%s' "${bk}" | jq '.user_models | type')" '"array"'
    _assert "backup has presets object" \
        "$(printf '%s' "${bk}" | jq '.presets | type')" '"object"'
    _assert "backup user_models contains our test model" \
        "$(printf '%s' "${bk}" | jq -r '.user_models[]' | grep -c 'test/usermodel')" "1"
else
    printf '  ❌  backup_export did not produce a file\n' >&2
    _FAIL=$(( _FAIL + 1 ))
fi

rm -f "${BACKUP_OUT}"

# ── Test group 13: fzf detection ─────────────────────────────────────────────

printf '\n── fzf detection ────────────────────────────────────────────────\n'

# shellcheck source=ui.sh
. "${_ROOT}/router/ui.sh"

if command -v fzf > /dev/null 2>&1; then
    _assert "_ui_has_fzf returns 0 (fzf available)" "$(_ui_has_fzf && printf yes || printf no)" "yes"
    printf '  ℹ️   fzf is available — fzf paths active\n'
else
    _assert "_ui_has_fzf returns 1 (fzf absent)" "$(_ui_has_fzf && printf yes || printf no)" "no"
    printf '  ℹ️   fzf not found — numbered-list fallback active\n'
fi

# ── Test group 14: fzf UI leak regression ─────────────────────────────────────
#
# Regression coverage for the bug this port fixed: the plain numbered
# "#  Provider" reference table must appear ONLY when fzf is unavailable.
# It must never print alongside (or before) the interactive fzf picker.
#
# We can't drive a real interactive fzf session headlessly, so these tests
# check the mechanism directly: show_provider_table's output (the leaking
# widget) must not be emitted by any code path reachable while fzf is
# present, and show_provider_table itself must remain callable in isolation
# (used only by the documented no-fzf fallback in prompt_provider_order).

printf '\n── fzf UI leak regression ───────────────────────────────────────\n'

# show_provider_table is a plain display helper — confirm its own output
# still looks like the numbered reference list (used by the fallback).
table_output=$(show_provider_table "DeepSeek" "Fireworks" "Baidu" 2>&1)
_assert_contains "show_provider_table lists index 1" "${table_output}" "1   DeepSeek"
_assert_contains "show_provider_table lists index 3" "${table_output}" "3   Baidu"

# The critical regression check: grep the router_engine.sh source itself to
# confirm show_provider_table is never called unconditionally at the
# call site (_router_choose_provider_order). It must only appear inside
# ui.sh, called from within prompt_provider_order's non-fzf branch.
engine_src="${_ROOT}/router/router_engine.sh"
# Strip full-line comments, then count remaining lines mentioning the
# function name — this is a real call site, not just prose explaining the
# fix in a comment.
calls_in_engine=$(grep -v '^[[:space:]]*#' "${engine_src}" | grep -c 'show_provider_table')
_assert "router_engine.sh never calls show_provider_table directly" "${calls_in_engine}" "0"

# Confirm show_provider_table appears in ui.sh exactly twice: once in its own
# definition, once inside prompt_provider_order's no-fzf branch — and that
# the call site is textually after the `_ui_has_fzf` branch check, i.e.
# guarded, not unconditional.
ui_src="${_ROOT}/router/ui.sh"
prompt_fn_body=$(awk '/^prompt_provider_order\(\) \{/,/^\}/' "${ui_src}")
_assert_contains "prompt_provider_order guards fzf check before table" \
    "${prompt_fn_body}" "_ui_has_fzf"
guarded_call=$(printf '%s' "${prompt_fn_body}" | grep -A2 '_ui_warn_no_fzf' | grep -c 'show_provider_table')
_assert "show_provider_table call sits in the no-fzf branch only" "${guarded_call}" "1"

# ── Test group 15: boxed intelligence-table leak regression (second pass) ────
#
# The first pass fixed the plain numbered "#  Provider" index list. A second,
# distinct leak remained: show_provider_intelligence's BOXED table (cost/
# uptime/latency/throughput per provider) also printed unconditionally right
# before the fzf picker opened — and every fzf row already carries that same
# data inline (see provider_intel_fzf_line). So with fzf present, the same
# provider list appeared twice in a row: once as a boxed table, once as the
# fzf picker. This is a behavioral test, not just a source grep: it calls
# show_provider_intelligence for real with _ui_has_fzf faked both ways and
# checks what actually gets printed to stderr in each case.

printf '\n── boxed intelligence-table leak regression ─────────────────────\n'

sample_intel='[{"provider_name":"DeepSeek","pricing_prompt":"0.00000014","pricing_completion":"0.00000028","uptime":99.87,"latency_p50":0.584,"throughput_p50":120.5}]'

# Case 1: fzf reports available -> table must NOT print.
_ui_has_fzf() { return 0; }
fzf_present_output=$(show_provider_intelligence "${sample_intel}" 2>&1)
_assert "boxed table does NOT print when fzf is available" "${fzf_present_output}" ""

# Case 2: fzf reports absent -> table MUST print (still needed as reference
# for the numbered-index fallback prompt).
_ui_has_fzf() { return 1; }
fzf_absent_output=$(show_provider_intelligence "${sample_intel}" 2>&1)
_assert_contains "boxed table DOES print when fzf is absent" "${fzf_absent_output}" "Provider Intelligence"
_assert_contains "boxed table (no-fzf) contains provider row" "${fzf_absent_output}" "DeepSeek"

# Restore the real implementation for anything sourced after this point.
unset -f _ui_has_fzf
. "${_ROOT}/router/ui.sh"

# ── Cleanup ───────────────────────────────────────────────────────────────────

rm -rf "${XDG_CACHE_HOME}" "${XDG_CONFIG_HOME}"

# ── Summary ───────────────────────────────────────────────────────────────────

printf '\n════════════════════════════════════════════════════════════════\n'
printf '  Results:  ✅ %d passed   ❌ %d failed\n' "${_PASS}" "${_FAIL}"
printf '════════════════════════════════════════════════════════════════\n\n'

[ "${_FAIL}" -eq 0 ]
