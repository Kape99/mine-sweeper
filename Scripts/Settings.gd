## Persistent settings store for the game.
## Registered as an autoload named "Settings".
## Values are saved to and loaded from user://settings.cfg via ConfigFile.
extends Node

const CONFIG_PATH: String = "user://settings.cfg"
const CONFIG_SECTION: String = "settings"

signal setting_changed(key: String, value: Variant)

var _config: ConfigFile = ConfigFile.new()

## Master volume (0.0 – 1.0).
var master_volume: float:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_persist("master_volume", master_volume)

## Music volume (0.0 – 1.0), applied on top of master_volume.
var music_volume: float:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_persist("music_volume", music_volume)

## SFX volume (0.0 – 1.0), applied on top of master_volume.
var sfx_volume: float:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_persist("sfx_volume", sfx_volume)

## Whether haptic feedback / vibration is enabled.
var vibration_enabled: bool:
	set(v):
		vibration_enabled = v
		_persist("vibration_enabled", vibration_enabled)

## Preferred graphics quality preset.
## Accepted values: "low", "medium", "high".
var graphics_quality: String:
	set(v):
		graphics_quality = v
		_persist("graphics_quality", graphics_quality)

## Whether the game runs fullscreen.
var fullscreen: bool:
	set(v):
		fullscreen = v
		_persist("fullscreen", fullscreen)
		_apply_fullscreen()

## Whether the board wraps on itself (toroidal) or has hard edges (classic).
var board_wrap: bool:
	set(v):
		board_wrap = v
		_persist("board_wrap", board_wrap)

## Player nickname (used for online / leaderboard display later).
var nickname: String:
	set(v):
		nickname = v.strip_edges()
		_persist("nickname", nickname)

## Language code, e.g. "en", "it".
var language: String:
	set(v):
		language = v
		_persist("language", language)


func _ready() -> void:
	_load()
	_apply_audio_buses()
	setting_changed.connect(_on_setting_changed)


## Apply current fullscreen setting immediately.
func _apply_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Apply volume settings to AudioServer buses immediately.
## Creates the bus if it doesn't exist yet (Godot always has at least
## one "Master" bus by default, so this is safe).
func _apply_audio_buses() -> void:
	var master_bus_idx: int = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(master_volume))


func _on_setting_changed(key: String, _value: Variant) -> void:
	match key:
		"master_volume":
			var idx: int = AudioServer.get_bus_index("Master")
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))
		"music_volume", "sfx_volume":
			# Stored for future AudioStreamPlayer bus routing.
			pass


## Read a value from the loaded ConfigFile.
func get_setting(key: String, default: Variant = null) -> Variant:
	if _config.has_section_key(CONFIG_SECTION, key):
		return _config.get_value(CONFIG_SECTION, key)
	return default


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


## Load config from disk, falling back to current in-memory defaults for
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

	# Apply loaded values to typed properties (clamps / applies side-effects)
	var raw_master: float = _config.get_value(CONFIG_SECTION, "master_volume", 1.0)
	master_volume = raw_master

	var raw_music: float = _config.get_value(CONFIG_SECTION, "music_volume", 1.0)
	music_volume = raw_music

	var raw_sfx: float = _config.get_value(CONFIG_SECTION, "sfx_volume", 1.0)
	sfx_volume = raw_sfx

	vibration_enabled = _config.get_value(CONFIG_SECTION, "vibration_enabled", true)
	graphics_quality = _config.get_value(CONFIG_SECTION, "graphics_quality", "medium")
	nickname = _config.get_value(CONFIG_SECTION, "nickname", "")
	language = _config.get_value(CONFIG_SECTION, "language", "en")

	var raw_fullscreen: bool = _config.get_value(CONFIG_SECTION, "fullscreen", false)
	fullscreen = raw_fullscreen  # triggers _apply_fullscreen via setter

	board_wrap = _config.get_value(CONFIG_SECTION, "board_wrap", true)


## Reset all settings to their in-code defaults and persist.
func reset_to_defaults() -> void:
	_apply_defaults()
	_save()


func _apply_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	vibration_enabled = true
	graphics_quality = "medium"
	fullscreen = false
	board_wrap = true
	nickname = ""
	language = "en"
