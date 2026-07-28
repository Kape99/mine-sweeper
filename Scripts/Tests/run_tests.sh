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
	godot --headless "$scene" 2>&1 | grep -v "^Godot Engine"
	status=${PIPESTATUS[0]}
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
