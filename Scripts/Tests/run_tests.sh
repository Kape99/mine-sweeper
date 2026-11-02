#!/usr/bin/env bash
# Runs every test scene under Scenes/Tests/ headlessly, one Godot process
# per scene (each TestCase quits its own process with exit code 0/1 after
# reporting results). Aggregates results and exits non-zero if any suite
# failed.
#
# Usage: ./Scripts/Tests/run_tests.sh
# Run from anywhere \u2014 the project root is resolved relative to this script.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/Scenes/Tests"

cd "$PROJECT_ROOT" || exit 1

# Per-suite time limit (seconds). A suite that fails to load (e.g. a script
# parse error) never reaches TestCase._report() and would otherwise hang.
SUITE_TIMEOUT="${SUITE_TIMEOUT:-60}"
if command -v timeout >/dev/null 2>&1; then
	run_limited() { timeout "$SUITE_TIMEOUT" "$@"; }
else
	run_limited() { "$@"; }
fi

# Rebuild the import / global class cache first. A stale .godot/ makes
# class_name types (MainMenu, ScreenManager, ...) unresolvable, so every
# scene fails to load and hangs silently.
echo "Importing project..."
if ! godot --headless --path "$PROJECT_ROOT" --import >/dev/null 2>&1; then
	echo "Project import failed" >&2
	exit 1
fi

overall_status=0
total=0
suite_failures=0

for scene in "$TESTS_DIR"/test_*.tscn; do
	[ -e "$scene" ] || continue
	total=$((total + 1))
	name="$(basename "$scene" .tscn)"
	echo "----------------------------------------"
	echo "Running: $name"
	echo "----------------------------------------"
	run_limited godot --headless --path "$PROJECT_ROOT" "$scene" 2>&1 | grep -v "^Godot Engine"
	status=${PIPESTATUS[0]}
	if [ "$status" -eq 124 ]; then
		echo "TIMEOUT: $name did not finish within ${SUITE_TIMEOUT}s"
	fi
	if [ "$status" -ne 0 ]; then
		suite_failures=$((suite_failures + 1))
		overall_status=1
	fi
done

echo ""
echo "========================================"
echo "Suites run: $total, failed: $suite_failures"
if [ "$overall_status" -eq 0 ]; then
	echo "RESULT: ALL SUITES PASSED"
else
	echo "RESULT: FAILURES PRESENT"
fi
echo "========================================"

exit "$overall_status"
