class_name MainMenu
extends Control

signal start_requested
signal settings_requested
signal quit_requested
signal wrap_mode_changed(wrap: bool)

const BOARD_TYPE_NAMES: PackedStringArray = ["Triangle", "Square", "Hexagon"]
const BOARD_MODE_NAMES: PackedStringArray = ["Classic", "Wrap"]
## Server UTC time, so the daily seed doesn't depend on the device clock.
const DAILY_TIME_URL: String = "https://timeapi.io/api/v1/time/current/utc"
## Seconds to wait for the time server before using the device's date.
const DAILY_TIME_TIMEOUT: float = 3.0

@onready var _background: ColorRect = $Background
@onready var _board_type_label: Label = $CenterContainer/Panel/BoardTypeRow/BoardTypeLabel
@onready var _board_type_prev: Button = $CenterContainer/Panel/BoardTypeRow/BoardTypePrev
@onready var _board_type_next: Button = $CenterContainer/Panel/BoardTypeRow/BoardTypeNext
@onready var _difficulty_label: Label = $CenterContainer/Panel/DifficultyRow/DifficultyLabel
@onready var _difficulty_prev: Button = $CenterContainer/Panel/DifficultyRow/DifficultyPrev
@onready var _difficulty_next: Button = $CenterContainer/Panel/DifficultyRow/DifficultyNext
@onready var _wrap_prev: Button = $CenterContainer/Panel/WrapRow/WrapPrev
@onready var _wrap_next: Button = $CenterContainer/Panel/WrapRow/WrapNext
@onready var _wrap_label: Label = $CenterContainer/Panel/WrapRow/WrapLabel
@onready var _seed_edit: LineEdit = $CenterContainer/Panel/SeedRow/SeedEdit
@onready var _start_button: Button = $CenterContainer/Panel/StartButton
@onready var _daily_button: Button = $CenterContainer/Panel/DailyChallenge
@onready var _https: HTTPRequest = $CenterContainer/Panel/DailyChallenge/HTTPRequest
@onready var _settings_button: Button = $CenterContainer/Panel/SettingsButton
@onready var _test: Button = $CenterContainer/Panel/test
@onready var _quit_button: Button = $CenterContainer/Panel/QuitButton


func _ready() -> void:
	_apply_theme_colors()
	GlobalState.theme_changed.connect(_apply_theme_colors)
	_sync_from_global_state()
	_connect_signals()
	_https.timeout = DAILY_TIME_TIMEOUT


## Colors the menu from the active color scheme: the same backdrop as the
## game screen. Re-run whenever the scheme changes.
func _apply_theme_colors() -> void:
	_background.color = GlobalState.scheme.background


func _process(_delta: float) -> void:
	# The debug settings (Settings screen) edit the raw board values while
	# this menu sits hidden in place; its process mode is restored before
	# it shows again, so this re-syncs the difficulty label on return.
	var difficulty: String = GlobalState.get_difficulty()
	if _difficulty_label.text != difficulty:
		_difficulty_label.text = difficulty


func _connect_signals() -> void:
	_board_type_prev.pressed.connect(_on_board_type_prev)
	_board_type_next.pressed.connect(_on_board_type_next)
	_difficulty_prev.pressed.connect(_on_difficulty_prev)
	_difficulty_next.pressed.connect(_on_difficulty_next)
	_wrap_prev.pressed.connect(_on_wrap_prev)
	_wrap_next.pressed.connect(_on_wrap_next)
	_seed_edit.text_changed.connect(_on_seed_changed)
	_start_button.pressed.connect(_on_start)
	_daily_button.pressed.connect(_on_daily)
	_https.request_completed.connect(_on_request_completed)
	_settings_button.pressed.connect(_on_settings)
	_test.pressed.connect(_on_test)
	_quit_button.pressed.connect(_on_quit)
func _sync_from_global_state() -> void:
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]
	_difficulty_label.text = GlobalState.get_difficulty()
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	_seed_edit.text = GlobalState.board_seed

func _set_seed(text: String) -> void:
	# Store normalized so "test7" and "TEST7 " share the same board.
	GlobalState.board_seed = text.strip_edges().to_upper()


func _on_board_type_prev() -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board - 1, BOARD_TYPE_NAMES.size())
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]


func _on_board_type_next() -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board + 1, BOARD_TYPE_NAMES.size())
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]


## Cycles through the difficulty presets (raw values live in the debug
## settings; a "Custom" difficulty jumps back to the nearest preset).
func _cycle_difficulty(step: int) -> void:
	var idx: int = GlobalState.DIFFICULTY_NAMES.find(GlobalState.get_difficulty())
	idx = posmod((0 if idx == -1 else idx) + step, GlobalState.DIFFICULTY_NAMES.size())
	GlobalState.apply_difficulty(GlobalState.DIFFICULTY_NAMES[idx])
	_difficulty_label.text = GlobalState.DIFFICULTY_NAMES[idx]


func _on_difficulty_prev() -> void:
	_cycle_difficulty(-1)


func _on_difficulty_next() -> void:
	_cycle_difficulty(1)


func _on_wrap_prev() -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	wrap_mode_changed.emit(GlobalState.board_wrap)


func _on_wrap_next() -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	wrap_mode_changed.emit(GlobalState.board_wrap)


func _on_seed_changed(text: String) -> void:
	_set_seed(text)

func _on_start() -> void:
	start_requested.emit()

func _on_daily() -> void:
	# Ignore repeat presses while the date request is still pending.
	if _https.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_seed_edit.clear()
	# Web builds can't reach the time API (it sends no CORS headers), so they
	# use the device clock straight away. Elsewhere, if the request can't
	# even be sent, fall back the same way.
	if OS.has_feature("web") or _https.request(DAILY_TIME_URL) != OK:
		_start_daily(Time.get_date_string_from_system(true))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# Any failure (no network, missing Android INTERNET permission, timeout,
	# unexpected payload) falls back to the device's UTC date, so the daily
	# challenge always starts.
	var date: String = Time.get_date_string_from_system(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json is Dictionary and json.get("utc_time") is String:
			date = (json["utc_time"] as String).split("T")[0]
	_start_daily(date)

func _start_daily(date: String) -> void:
	_set_seed(date)
	start_requested.emit()

func _on_settings() -> void:
	settings_requested.emit()

func _on_test() -> void:
	var res := await Talo.player_auth.register("test", "test")

func _on_quit() -> void:
	quit_requested.emit()
