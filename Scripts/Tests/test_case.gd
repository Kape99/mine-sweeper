## Minimal, dependency-free test-case base class.
## Subclasses override [method run] and call the assert_* helpers.
## Each test scene's root script extends this, runs in [method _ready],
## then quits the process with exit code 0 (all passed) or 1 (any failed).
## Run via: godot --headless <scene>.tscn
class_name TestCase
extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n=== %s ===" % get_script().resource_path.get_file().get_basename())
	run()
	_report()


## Override in subclasses to perform assertions.
func run() -> void:
	pass


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: " + message)
	else:
		_failed += 1
		print("  FAIL: " + message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_passed += 1
		print("  PASS: " + message)
	else:
		_failed += 1
		print("  FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_gt(actual: float, threshold: float, message: String) -> void:
	if actual > threshold:
		_passed += 1
		print("  PASS: " + message)
	else:
		_failed += 1
		print("  FAIL: %s (expected > %s, got %s)" % [message, str(threshold), str(actual)])


func _report() -> void:
	print("--- %d passed, %d failed ---" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
