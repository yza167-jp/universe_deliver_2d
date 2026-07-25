#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXPECTED_GODOT_VERSION="4.7.1.stable"

fail() {
  printf '[m1-regression] ERROR: %s\n' "$1" >&2
  exit 1
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

run_godot_checked() {
  local label="$1"
  shift
  local command_output=""
  local command_status=0

  printf '[m1-regression] %s\n' "${label}"
  command_output="$("${GODOT_EXECUTABLE}" "$@" 2>&1)" || command_status=$?
  printf '%s\n' "${command_output}"
  if [[ ${command_status} -ne 0 ]]; then
    fail "${label} exited with status ${command_status}."
  fi
  if printf '%s\n' "${command_output}" | grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:)'; then
    fail "${label} emitted a Godot error."
  fi
}

GODOT_EXECUTABLE="$(resolve_godot)"
GODOT_VERSION="$("${GODOT_EXECUTABLE}" --version | head -n 1 | tr -d '\r')"

case "${GODOT_VERSION}" in
  "${EXPECTED_GODOT_VERSION}"*) ;;
  *)
    fail "Godot ${EXPECTED_GODOT_VERSION} is required; found ${GODOT_VERSION}."
    ;;
esac

run_godot_checked \
  "Typed M1 systems, registry, localization, order, reward, and isolation contracts" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/test_runner.gd

run_godot_checked \
  "Schema v1-to-v2 completed and unfinished migration" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/save_schema_v2_migration_smoke_runner.gd

run_godot_checked \
  "Multi-planet order terminal and cockpit navigation" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/m1_catalog_navigation_smoke_runner.gd

run_godot_checked \
  "Codex, souvenirs, station state, and modal restore" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t106_station_collections_smoke_runner.gd

run_godot_checked \
  "Delivery Lab low-altitude drop" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/delivery_lab_smoke_runner.gd

run_godot_checked \
  "Express timer, pause, HUD, and settlement" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t108_express_order_smoke_runner.gd

run_godot_checked \
  "M1 scenario state, reset, target scenes, and storage isolation" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t109_m1_debug_smoke_runner.gd

run_godot_checked \
  "Red Sand revisit post-M0 packet, dialogue, route outline, and isolated preview" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t110_red_sand_revisit_smoke_runner.gd

run_godot_checked \
  "High-voltage shielding ownership, installation, capability, visual, and save contract" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t111_high_voltage_shielding_smoke_runner.gd

run_godot_checked \
  "Red Sand revisit short route, branch settlement, station growth, and Continue" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t112_red_sand_revisit_flow_smoke_runner.gd

run_godot_checked \
  "Archive terminal catalog, modal focus, Lao Pi briefing, and Continue" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/t113_archive_terminal_smoke_runner.gd

for scenario_id in \
  red_sand_revisit \
  white_noise_catalog \
  canopy_catalog \
  tidal_catalog \
  low_altitude_drop \
  express_order
do
  run_godot_checked \
    "Direct M1 debug boot: ${scenario_id}" \
    --headless --path "${PROJECT_ROOT}" --quit-after 2 -- \
    "--m1-debug=${scenario_id}"
done

run_godot_checked \
  "M0 New Game, first order, flight, settlement, return, and Continue" \
  --headless --path "${PROJECT_ROOT}" --script res://tests/smoke/m0_full_flow_smoke_runner.gd

printf '[m1-regression] PASS: all named M1 foundation and M0 baseline subsystems passed.\n'
