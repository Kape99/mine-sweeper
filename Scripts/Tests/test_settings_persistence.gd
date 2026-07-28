## Verifies the Settings autoload: property setters clamp/persist, the
## setting_changed signal fires, and values round-trip through
## user://settings.cfg via a fresh ConfigFile read.
## NOTE: mutates the real Settings.cfg on disk for the duration of the
## test, then restores original values \u2014 safe to run repeatedly.
extends TestCase


func run() -> void:
	var original_volume: float = Settings.master_volume
	var original_wrap: bool = Settings.board_wrap

	_test_clamping()
	_test_signal_emission()
	_test_persistence_round_trip()

	# Restore whatever was there before this test ran.
	Settings.master_volume = original_volume
	Settings.board_wrap = original_wrap


func _test_clamping() -> void:
	Settings.master_volume = 5.0  # out of [0, 1] range
	assert_eq(Settings.master_volume, 1.0, "master_volume clamps values above 1.0")

	Settings.master_volume = -5.0
	assert_eq(Settings.master_volume, 0.0, "master_volume clamps values below 0.0")


func _test_signal_emission() -> void:
	# NOTE: use a mutable Array (captured by reference) instead of plain
	# local vars — GDScript lambdas snapshot value-type locals (String,
	# bool, ...) by value, so reassigning them inside the lambda would not
	# be visible here.
	var captured: Array = ["", null]
	var handler: Callable = func(key: String, value: Variant) -> void:
		captured[0] = key
		captured[1] = value
	Settings.setting_changed.connect(handler)

	Settings.board_wrap = false
	assert_eq(captured[0], "board_wrap", "setting_changed emits the correct key")
	assert_eq(captured[1], false, "setting_changed emits the correct value")

	Settings.setting_changed.disconnect(handler)


func _test_persistence_round_trip() -> void:
	Settings.board_wrap = false
	Settings.master_volume = 0.42

	# Read back from disk with a fresh ConfigFile, bypassing the Settings
	# singleton's in-memory state entirely, to prove _save() actually wrote.
	var fresh: ConfigFile = ConfigFile.new()
	var err: Error = fresh.load("user://settings.cfg")
	assert_eq(err, OK, "settings.cfg loads successfully from disk")

	var disk_wrap: bool = fresh.get_value("settings", "board_wrap", true)
	assert_eq(disk_wrap, false, "board_wrap=false was persisted to disk")

	var disk_volume: float = fresh.get_value("settings", "master_volume", -1.0)
	assert_eq(disk_volume, 0.42, "master_volume=0.42 was persisted to disk")
