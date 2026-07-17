#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXPECTED_GODOT_VERSION="4.7.1.stable"

fail() {
  printf '[check] ERROR: %s\n' "$1" >&2
  exit 1
}

run_step() {
  local label="$1"
  shift

  printf '[check] %s\n' "${label}"
  if ! "$@"; then
    printf '[check] FAILED: %s\n' "${label}" >&2
    exit 1
  fi
}

run_godot_checked() {
  local command_output=""
  local command_status=0

  command_output="$("${GODOT_EXECUTABLE}" "$@" 2>&1)" || command_status=$?
  printf '%s\n' "${command_output}"

  if [[ ${command_status} -ne 0 ]]; then
    return "${command_status}"
  fi
  if printf '%s\n' "${command_output}" | grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:)'; then
    return 1
  fi
  return 0
}

resolve_godot() {
  local candidate=""

  if [[ -n "${GODOT_BIN:-}" ]]; then
    [[ -x "${GODOT_BIN}" ]] || fail "GODOT_BIN is not executable: ${GODOT_BIN}"
    printf '%s\n' "${GODOT_BIN}"
    return
  fi

  for candidate in godot godot4; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return
    fi
  done

  candidate="/Applications/Godot.app/Contents/MacOS/Godot"
  if [[ -x "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return
  fi

  fail "Godot was not found. Set GODOT_BIN to the Godot 4.7.1 executable."
}

GODOT_EXECUTABLE="$(resolve_godot)"
GODOT_VERSION="$("${GODOT_EXECUTABLE}" --version | head -n 1 | tr -d '\r')"

case "${GODOT_VERSION}" in
  "${EXPECTED_GODOT_VERSION}"*) ;;
  *)
    fail "Godot ${EXPECTED_GODOT_VERSION} is required; found ${GODOT_VERSION}."
    ;;
esac

printf '[check] Using Godot %s\n' "${GODOT_VERSION}"

run_step \
  "Headless project import" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --import

GDSCRIPT_FILES=()
while IFS= read -r script_path; do
  GDSCRIPT_FILES+=("${script_path}")
done < <(cd "${PROJECT_ROOT}" && find . -type f -name '*.gd' -not -path './.godot/*' | sort)

[[ ${#GDSCRIPT_FILES[@]} -gt 0 ]] || fail "No GDScript files were found to parse."

for script_path in "${GDSCRIPT_FILES[@]}"; do
  resource_path="res://${script_path#./}"
  run_step \
    "Parse ${resource_path}" \
    run_godot_checked --headless --path "${PROJECT_ROOT}" --check-only --script "${resource_path}"
done

run_step \
  "Unit and scene smoke tests" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/test_runner.gd

run_step \
  "Dialogue UI layout and Chinese glyph smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/dialogue_ui_smoke_runner.gd

run_step \
  "Debug settings interaction and layout smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/debug_settings_panel_smoke_runner.gd

run_step \
  "Station hub layout and reachability smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/station_hub_smoke_runner.gd

run_step \
  "Station player movement and interaction smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/station_player_smoke_runner.gd

run_step \
  "Lao Pi station tutorial recovery and persistence smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/station_tutorial_smoke_runner.gd

run_step \
  "Red Sand order terminal state and content smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/order_terminal_smoke_runner.gd

run_step \
  "Fixed ship loadout and departure readiness smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/ship_loadout_smoke_runner.gd

run_step \
  "Interactive first-person cockpit layout and input smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/cockpit_smoke_runner.gd

run_step \
  "Gate A station-to-cockpit playable path smoke test" \
  run_godot_checked --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/station_gate_a_smoke_runner.gd

run_step "Working tree whitespace check" git -C "${PROJECT_ROOT}" diff --check
run_step "Index whitespace check" git -C "${PROJECT_ROOT}" diff --cached --check

printf '[check] PASS: import, parsing, tests, and whitespace checks completed.\n'
