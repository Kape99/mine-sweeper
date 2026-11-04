## Persistent settings store for the game.
## Registered as an autoload named "Settings".
## Values are saved to and loaded from user://settings.cfg via ConfigFile.
extends Node

const CONFIG_PATH: String = "user://settings.cfg"
const CONFIG_SECTION: String = "settings"

## Bump when a stored setting needs a one-time upgrade; see [method _migrate].
const SETTINGS_VERSION: int = 1

signal setting_changed(key: String, value: Variant)

var _config: ConfigFile = ConfigFile.new()

## Maximum distance (px) between touch-down and touch-up to register a tap.
var tap_threshold: float:
	set(v):
		tap_threshold = clampf(v, 1.0, 100.0)
		_persist("tap_threshold", tap_threshold)

## Time (ms) a finger must stay down to trigger a long-press defuse toggle.
var long_press_threshold_ms: int:
	set(v):
		long_press_threshold_ms = clampi(v, 50, 5000)
		_persist("long_press_threshold_ms", long_press_threshold_ms)

## Whether a double tap (instead of a single tap) opens a cell. A double tap
## always opens, even in defuse mode or on a flagged cell.
var use_double_tap: bool:
	set(v):
		use_double_tap = v
		_persist("use_double_tap", use_double_tap)

## Max time (ms) between two taps to count as a double tap.
var double_tap_window_ms: int:
	set(v):
		double_tap_window_ms = clampi(v, 150, 2000)
		_persist("double_tap_window_ms", double_tap_window_ms)


func _ready() -> void:
	_load()
	setting_changed.connect(_on_setting_changed)


## Internal setter that persists and emits the signal.
func _persist(key: String, value: Variant) -> void:
	_config.set_value(CONFIG_SECTION, key, value)
	_save()
	setting_changed.emit(key, value)


## Save config to disk.
func _save() -> void:
	var err: Error = _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("Settings: failed to save config (%s)" % error_string(err))


## Load config from disk, falling back to current in-code defaults for
## anything that isn't stored yet.
func _load() -> void:
	var err: Error = _config.load(CONFIG_PATH)
	if err == ERR_FILE_NOT_FOUND:
		_apply_defaults()
		_save()
		return
	if err != OK:
		push_warning("Settings: failed to load config (%s)" % error_string(err))
		return

	tap_threshold = _config.get_value(CONFIG_SECTION, "tap_threshold", 15.0)
	long_press_threshold_ms = _config.get_value(CONFIG_SECTION, "long_press_threshold_ms", 400)
	use_double_tap = _config.get_value(CONFIG_SECTION, "use_double_tap", true)
	double_tap_window_ms = _config.get_value(CONFIG_SECTION, "double_tap_window_ms", 350)
	_migrate(_config.get_value(CONFIG_SECTION, "settings_version", 0))


## One-time upgrades for configs saved by older versions.
func _migrate(from_version: int) -> void:
	if from_version >= SETTINGS_VERSION:
		return
	if from_version < 1:
		# v1: double tap became the default. Older installs saved the old
		# default (off) on first launch, so switch it on once.
		use_double_tap = true
	_config.set_value(CONFIG_SECTION, "settings_version", SETTINGS_VERSION)
	_save()


## Reset all settings to their in-code defaults and persist.
func reset_to_defaults() -> void:
	_apply_defaults()
	_save()


func _apply_defaults() -> void:
	tap_threshold = 15.0
	long_press_threshold_ms = 400
	use_double_tap = true
	double_tap_window_ms = 350
	_config.set_value(CONFIG_SECTION, "settings_version", SETTINGS_VERSION)


## Reads a stored setting by key (fallback to default if missing).
func get_setting(key: String, default: Variant = null) -> Variant:
	if _config.has_section_key(CONFIG_SECTION, key):
		return _config.get_value(CONFIG_SECTION, key)
	return default


func _on_setting_changed(key: String, _value: Variant) -> void:
	pass
