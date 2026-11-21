@tool
class_name MainMenu
extends Control

signal start_requested(board: int, cols: int, rows: int, mine_perc: float, board_wrap: bool, board_seed: String, is_daily: bool)
signal settings_requested
signal wrap_mode_changed(wrap: bool)

const SegmentedButton = preload("res://Scripts/GUI/Widgets/segmented_button.gd")

const BOARD_TYPE_NAMES: PackedStringArray = ["Triangle", "Square", "Hexagon"]
const BOARD_MODE_NAMES: PackedStringArray = ["Solid", "Wrap"]
const DIFFICULTY_CHIPS: PackedStringArray = ["Easy", "Medium", "Hard"]

const DAILY_TIME_URL: String = "https://timeapi.io/api/v1/time/current/utc"
const DAILY_TIME_TIMEOUT: float = 3.0

const DAILY_MIN_SIZE: int = 10
const DAILY_MAX_SIZE: int = 25
const DAILY_MIN_MINES: float = 0.10
const DAILY_MAX_MINES: float = 0.20

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $TopBar/TitleLabel
@onready var _settings_button: Button = $TopBar/SettingsButton
@onready var _account_button: Button = $TopBar/AccountButton
@onready var _daily_label: Label = $CenterContainer/Panel/DailyCard/DailyVBox/DailyLabel
@onready var _daily_summary: Label = $CenterContainer/Panel/DailyCard/DailyVBox/DailySummary
@onready var _streak_badge: Label = $CenterContainer/Panel/DailyCard/DailyVBox/StreakBadge
@onready var _daily_button: Button = $CenterContainer/Panel/DailyCard/DailyVBox/DailyPlayRow/DailyChallenge
@onready var _leaderboard_button: Button = $CenterContainer/Panel/DailyCard/DailyVBox/DailyPlayRow/LeaderboardButton
@onready var _https: HTTPRequest = $CenterContainer/Panel/DailyCard/DailyVBox/DailyPlayRow/DailyChallenge/HTTPRequest
@onready var _board_type_segmented: SegmentedButton = $CenterContainer/Panel/SettingsCard/SettingsVBox/BoardTypeSegmented
@onready var _difficulty_segmented: SegmentedButton = $CenterContainer/Panel/SettingsCard/SettingsVBox/DifficultySegmented
@onready var _edges_segmented: SegmentedButton = $CenterContainer/Panel/SettingsCard/SettingsVBox/EdgesPlayRow/EdgesSegmented
@onready var _difficulty_summary: Label = $CenterContainer/Panel/SettingsCard/SettingsVBox/DifficultySummary
@onready var _start_button: Button = $CenterContainer/Panel/SettingsCard/SettingsVBox/EdgesPlayRow/StartButton



func _ready() -> void:
	_apply_theme_colors()
	if Engine.is_editor_hint():
		return
	GlobalState.theme_changed.connect(_apply_theme_colors)
	_sync_from_global_state()
	_connect_signals()
	_https.timeout = DAILY_TIME_TIMEOUT
	_update_daily_date_label()


func _apply_theme_colors() -> void:
	_background.color = GlobalState.scheme.background

	var accent: Color = GlobalState.scheme.accent
	var primary: Color = GlobalState.scheme.primary
	var surface: Color = GlobalState.scheme.surface
	var text: Color = GlobalState.scheme.hud_text
	var inverse: Color = GlobalState.scheme.inverse_text

	_title_label.add_theme_color_override("font_color", text)
	_settings_button.add_theme_color_override("font_color", text)
	_account_button.add_theme_color_override("font_color", text)
	_difficulty_summary.add_theme_color_override("font_color", text.darkened(0.25))

	var daily_card_style: StyleBoxFlat = StyleBoxFlat.new()
	daily_card_style.bg_color = text.darkened(0.1)
	daily_card_style.corner_radius_top_left = 16
	daily_card_style.corner_radius_top_right = 16
	daily_card_style.corner_radius_bottom_right = 16
	daily_card_style.corner_radius_bottom_left = 16
	daily_card_style.content_margin_left = 20
	daily_card_style.content_margin_top = 20
	daily_card_style.content_margin_right = 20
	daily_card_style.content_margin_bottom = 20
	$CenterContainer/Panel/DailyCard.add_theme_stylebox_override("panel", daily_card_style)

	var daily_button_style: StyleBoxFlat = StyleBoxFlat.new()
	daily_button_style.bg_color = primary
	daily_button_style.corner_radius_top_left = 12
	daily_button_style.corner_radius_top_right = 12
	daily_button_style.corner_radius_bottom_right = 12
	daily_button_style.corner_radius_bottom_left = 12
	daily_button_style.content_margin_left = 12
	daily_button_style.content_margin_right = 12
	var daily_hover: StyleBoxFlat = daily_button_style.duplicate()
	daily_hover.bg_color = primary.lightened(0.1)
	var daily_pressed: StyleBoxFlat = daily_button_style.duplicate()
	daily_pressed.bg_color = primary.darkened(0.1)
	_daily_button.add_theme_stylebox_override("normal", daily_button_style)
	_daily_button.add_theme_stylebox_override("hover", daily_hover)
	_daily_button.add_theme_stylebox_override("pressed", daily_pressed)
	_daily_button.add_theme_color_override("font_color", text)

	var trophy_style: StyleBoxFlat = StyleBoxFlat.new()
	trophy_style.bg_color = Color(0, 0, 0, 0)
	trophy_style.border_width_left = 2
	trophy_style.border_width_top = 2
	trophy_style.border_width_right = 2
	trophy_style.border_width_bottom = 2
	trophy_style.border_color = primary
	trophy_style.corner_radius_top_left = 12
	trophy_style.corner_radius_top_right = 12
	trophy_style.corner_radius_bottom_right = 12
	trophy_style.corner_radius_bottom_left = 12
	trophy_style.content_margin_left = 8
	trophy_style.content_margin_right = 8
	var trophy_hover: StyleBoxFlat = trophy_style.duplicate()
	trophy_hover.bg_color = primary.darkened(0.55)
	var trophy_pressed: StyleBoxFlat = trophy_style.duplicate()
	trophy_pressed.bg_color = primary.darkened(0.45)
	_leaderboard_button.add_theme_stylebox_override("normal", trophy_style)
	_leaderboard_button.add_theme_stylebox_override("hover", trophy_hover)
	_leaderboard_button.add_theme_stylebox_override("pressed", trophy_pressed)
	_leaderboard_button.add_theme_color_override("font_color", primary)

	_daily_label.add_theme_color_override("font_color", inverse)
	_daily_summary.add_theme_color_override("font_color", inverse)
	_streak_badge.add_theme_color_override("font_color", inverse)

	var settings_card_style: StyleBoxFlat = StyleBoxFlat.new()
	settings_card_style.bg_color = surface
	settings_card_style.corner_radius_top_left = 16
	settings_card_style.corner_radius_top_right = 16
	settings_card_style.corner_radius_bottom_right = 16
	settings_card_style.corner_radius_bottom_left = 16
	settings_card_style.content_margin_left = 16
	settings_card_style.content_margin_top = 16
	settings_card_style.content_margin_right = 16
	settings_card_style.content_margin_bottom = 16
	$CenterContainer/Panel/SettingsCard.add_theme_stylebox_override("panel", settings_card_style)

	_sync_segmented_widgets()
	_update_difficulty_summary()


func _connect_signals() -> void:
	_start_button.pressed.connect(_on_start)
	_daily_button.pressed.connect(_on_daily)
	_leaderboard_button.pressed.connect(_on_leaderboard)
	_settings_button.pressed.connect(_on_settings)
	_account_button.pressed.connect(_on_account)
	_https.request_completed.connect(_on_request_completed)
	_board_type_segmented.segment_selected.connect(_on_board_type_selected)
	_difficulty_segmented.segment_selected.connect(_on_difficulty_selected)
	_edges_segmented.segment_selected.connect(_on_edges_selected)


func _sync_from_global_state() -> void:
	_sync_segmented_widgets()
	_update_difficulty_summary()


func _sync_segmented_widgets() -> void:
	var diff: String = GlobalState.get_difficulty()
	var diff_index: int = DIFFICULTY_CHIPS.find(diff)
	if diff_index < 0:
		diff_index = 1  # default Medium
	_difficulty_segmented.set_selected(diff_index)

	var edge_index: int = 1 if GlobalState.board_wrap else 0
	_edges_segmented.set_selected(edge_index)

func _on_board_type_selected(index: int) -> void:
	GlobalState.selected_board = index
	Settings.save_menu_state()


func _on_difficulty_selected(index: int) -> void:
	GlobalState.apply_difficulty(DIFFICULTY_CHIPS[index])
	_update_difficulty_summary()
	Settings.save_menu_state()


func _on_edges_selected(index: int) -> void:
	GlobalState.board_wrap = index == 1
	wrap_mode_changed.emit(GlobalState.board_wrap)
	Settings.save_menu_state()


func _set_chip_active(chip: Button, active: bool) -> void:
	chip.toggle_mode = true
	chip.button_pressed = active
	var accent: Color = GlobalState.scheme.accent
	var text: Color = GlobalState.scheme.hud_text
	if active:
		chip.add_theme_color_override("font_color", text)
		chip.add_theme_stylebox_override("normal", _chip_stylebox(accent))
		chip.add_theme_stylebox_override("hover", _chip_stylebox(accent.lightened(0.1)))
		chip.add_theme_stylebox_override("pressed", _chip_stylebox(accent.darkened(0.1)))
	else:
		chip.add_theme_color_override("font_color", text.darkened(0.35))
		chip.add_theme_stylebox_override("normal", _chip_stylebox(accent.lightened(0.45)))
		chip.add_theme_stylebox_override("hover", _chip_stylebox(accent.lightened(0.5)))
		chip.add_theme_stylebox_override("pressed", _chip_stylebox(accent.lightened(0.4)))


func _update_difficulty_summary() -> void:
	var mines: int = max(1, int(round(GlobalState.board_cols * GlobalState.board_rows * GlobalState.bomb_percentage)))
	_difficulty_summary.text = "%d×%d · %d mines" % [GlobalState.board_cols, GlobalState.board_rows, mines]


func _chip_stylebox(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


func _on_start() -> void:
	start_requested.emit(GlobalState.selected_board, GlobalState.board_cols, GlobalState.board_rows, GlobalState.bomb_percentage, GlobalState.board_wrap, GlobalState.board_seed, false)

func _on_daily() -> void:
	if _https.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	# Web builds can't reach the time API (it sends no CORS headers), so they
	# use the device clock straight away. Elsewhere, if the request can't
	# even be sent, fall back the same way.
	if OS.has_feature("web") or _https.request(DAILY_TIME_URL) != OK:
		_start_daily(Time.get_date_string_from_system(true))


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var date: String = Time.get_date_string_from_system(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json is Dictionary and json.get("utc_time") is String:
			date = (json["utc_time"] as String).split("T")[0]
	_start_daily(date)

## Starts the daily challenge for [param date] (YYYY-MM-DD). The date is the
## seed for both the board settings and the mine layout. It's passed to the
## game only, never stored in [member GlobalState.board_seed], so the menu's
## own seed (and the next PLAY) are left as the player set them.
func _start_daily(date: String) -> void:
	var daily_seed: String = date.strip_edges().to_upper()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(daily_seed.hash())
	var board_wrap: bool = true
	var selected_board: int = rng.randi_range(0, BOARD_TYPE_NAMES.size() - 1)
	var board_rows: int = rng.randi_range(DAILY_MIN_SIZE, DAILY_MAX_SIZE)
	var board_cols: int = rng.randi_range(DAILY_MIN_SIZE, DAILY_MAX_SIZE)
	var bomb_percentage: float = rng.randf_range(DAILY_MIN_MINES, DAILY_MAX_MINES)
	start_requested.emit(selected_board, board_cols, board_rows, bomb_percentage, board_wrap, daily_seed, true)


func _update_daily_date_label() -> void:
	var date: Dictionary = Time.get_datetime_dict_from_system(false)
	var month_names: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var weekday_names: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	_daily_label.text = "DAILY CHALLENGE · %s %d %s" % [weekday_names[date.weekday], date.day, month_names[date.month - 1]]
	_update_daily_preview()


func _update_daily_preview() -> void:
	# Use today's UTC date as the daily seed to preview the same board
	# the user will play when tapping PLAY DAILY.
	var date: String = Time.get_date_string_from_system(true)
	var rng: RandomNumberGenerator = _daily_rng_for_date(date)
	var selected_board: int = rng.randi_range(0, BOARD_TYPE_NAMES.size() - 1)
	var board_rows: int = rng.randi_range(DAILY_MIN_SIZE, DAILY_MAX_SIZE)
	var board_cols: int = rng.randi_range(DAILY_MIN_SIZE, DAILY_MAX_SIZE)
	var bomb_percentage: float = rng.randf_range(DAILY_MIN_MINES, DAILY_MAX_MINES)
	var mines: int = max(1, int(round(board_cols * board_rows * bomb_percentage)))
	var board_name: String = BOARD_TYPE_NAMES[selected_board].to_lower()
	_daily_summary.text = "%s grid · %d×%d · %d mines" % [board_name, board_cols, board_rows, mines]


func _daily_rng_for_date(date: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_text: String = date.strip_edges().to_upper()
	# Match GlobalState.get_seed_value() exactly so preview and play use the same RNG sequence.
	var seed_value: int = absi(seed_text.hash()) if not seed_text.is_empty() else 0
	rng.seed = seed_value
	return rng


func _on_leaderboard() -> void:
	pass


func _on_account() -> void:
	pass


func _on_settings() -> void:
	settings_requested.emit()
