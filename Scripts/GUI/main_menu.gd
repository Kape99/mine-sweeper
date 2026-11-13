## Main menu, built around two actions: today's daily challenge (with the
## player's time and rank) and PLAY, which starts a game with the last
## settings. The settings themselves live in the New game sheet, opened
## from the summary line under PLAY; account and settings sit in the top
## bar.
class_name MainMenu
extends Control

signal start_requested(board: int, cols: int, rows: int, mine_perc: float, board_wrap: bool, board_seed: String, is_daily: bool)
signal new_game_requested
signal settings_requested
signal account_requested

const FinalScreen = preload("res://Scripts/GUI/final_screen.gd")

const BOARD_TYPE_NAMES: PackedStringArray = ["Triangle", "Square", "Hexagon"]
const BOARD_MODE_NAMES: PackedStringArray = ["Classic", "Wrap"]
const MONTH_NAMES: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## Server UTC time, so the daily seed doesn't depend on the device clock.
const DAILY_TIME_URL: String = "https://timeapi.io/api/v1/time/current/utc"
## Seconds to wait for the time server before using the device's date.
const DAILY_TIME_TIMEOUT: float = 3.0

const DAILY_MIN_SIZE : int = 10
const DAILY_MAX_SIZE : int = 25
const DAILY_MIN_MINES : float = 0.10
const DAILY_MAX_MINES : float = 0.20

const PANEL: String = "Margin/Layout/CenterContainer/Panel"

@onready var _background: ColorRect = $Background
@onready var _account_button: Button = $Margin/Layout/TopBar/AccountButton
@onready var _settings_button: Button = $Margin/Layout/TopBar/SettingsButton
@onready var _daily_info: Label = get_node(PANEL + "/DailyCard/DailyBox/DailyInfo")
@onready var _daily_status: Label = get_node(PANEL + "/DailyCard/DailyBox/DailyStatus")
@onready var _daily_button: Button = get_node(PANEL + "/DailyCard/DailyBox/DailyButton")
@onready var _https: HTTPRequest = get_node(PANEL + "/DailyCard/DailyBox/DailyButton/HTTPRequest")
@onready var _start_button: Button = get_node(PANEL + "/PlayBox/PlayButton")
@onready var _game_summary: Button = get_node(PANEL + "/PlayBox/GameSummary")

## Bumped on every daily status refresh, so a slow answer for an older
## refresh (e.g. from before logging out) is dropped.
var _daily_request_id: int = 0


func _ready() -> void:
	_apply_theme_colors()
	GlobalState.theme_changed.connect(_apply_theme_colors)
	_connect_signals()
	_https.timeout = DAILY_TIME_TIMEOUT
	_account_button.text = _account_text()
	_game_summary.text = _summary_text()
	_update_daily_info()
	_refresh_daily_status()


## Colors the menu from the active color scheme: the same backdrop as the
## game screen. Re-run whenever the scheme changes.
func _apply_theme_colors() -> void:
	_background.color = GlobalState.scheme.background


func _process(_delta: float) -> void:
	# The New game sheet and the debug settings edit the board settings, and
	# the Account screen logs in and out, while this menu waits hidden in
	# place (Talo also restores a saved session at startup). Its process mode
	# is restored before it shows again, so this re-syncs on return.
	var summary: String = _summary_text()
	if _game_summary.text != summary:
		_game_summary.text = summary
	var account: String = _account_text()
	if _account_button.text != account:
		_account_button.text = account
		_refresh_daily_status()


func _connect_signals() -> void:
	_account_button.pressed.connect(account_requested.emit)
	_settings_button.pressed.connect(settings_requested.emit)
	_daily_button.pressed.connect(_on_daily)
	_https.request_completed.connect(_on_request_completed)
	_start_button.pressed.connect(_on_start)
	_game_summary.pressed.connect(new_game_requested.emit)
	# Back from a game: the player may have just sent a new time.
	visibility_changed.connect(func() -> void:
		if visible:
			_update_daily_info()
			_refresh_daily_status())


func _account_text() -> String:
	return AccountMenu.player_name().to_upper() if AccountMenu.is_logged_in() else "LOG IN"


## One line describing what PLAY starts, e.g. "Square · Medium · Wrap".
func _summary_text() -> String:
	var parts: PackedStringArray = [
		BOARD_TYPE_NAMES[GlobalState.selected_board],
		GlobalState.get_difficulty(),
		BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0],
	]
	if not GlobalState.board_seed.is_empty():
		parts.append("Seed " + GlobalState.board_seed)
	return " · ".join(parts) + "  ›"


func _on_start() -> void:
	start_requested.emit(GlobalState.selected_board, GlobalState.board_cols, GlobalState.board_rows, GlobalState.bomb_percentage, GlobalState.board_wrap, GlobalState.board_seed, false)


# --- Daily challenge ---------------------------------------------------------

## Board settings of the daily challenge for [param date] (YYYY-MM-DD). The
## date seeds both these settings and the mine layout.
static func daily_settings(date: String) -> Dictionary:
	var daily_seed: String = date.strip_edges().to_upper()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(daily_seed.hash())
	# Draw order matters: changing it changes every past and future daily.
	var board: int = rng.randi_range(0, BOARD_TYPE_NAMES.size() - 1)
	var rows: int = rng.randi_range(DAILY_MIN_SIZE, DAILY_MAX_SIZE)
	var cols: int = rng.randi_range(DAILY_MIN_SIZE, DAILY_MAX_SIZE)
	var mine_perc: float = rng.randf_range(DAILY_MIN_MINES, DAILY_MAX_MINES)
	return { seed = daily_seed, board = board, rows = rows, cols = cols, mine_perc = mine_perc }


## Shows today's date and board on the card, from the device's UTC date
## (the same fallback the daily itself uses).
func _update_daily_info() -> void:
	var date: String = Time.get_date_string_from_system(true)
	var daily: Dictionary = daily_settings(date)
	var parts: PackedStringArray = date.split("-")
	var day_label: String = date
	if parts.size() == 3:
		day_label = "%s %d" % [MONTH_NAMES[clampi(parts[1].to_int() - 1, 0, 11)], parts[2].to_int()]
	_daily_info.text = "%s · %s · %d × %d" % [day_label, BOARD_TYPE_NAMES[daily.board], daily.cols, daily.rows]


## Shows the player's time and rank for today, if they've sent one. The
## leaderboard resets daily, so its live entries are all from today.
func _refresh_daily_status() -> void:
	_daily_request_id += 1
	var request_id: int = _daily_request_id
	if not AccountMenu.is_logged_in():
		_daily_status.text = "Log in to join the leaderboard"
		return
	var alias_id: int = Talo.current_alias.id
	_daily_status.text = "Checking your time..."

	# The first page holds everyone near the top; its positions are ranks.
	var page: LeaderboardsAPI.EntriesPage = await Talo.leaderboards.get_entries(FinalScreen.TALO_LEADERBOARD)
	if request_id != _daily_request_id:
		return
	if page == null:
		_daily_status.text = "Leaderboard offline"
		return
	for entry: TaloLeaderboardEntry in page.entries:
		if entry.player_alias and entry.player_alias.id == alias_id:
			_daily_status.text = "Your time: %s · #%d" % [BoardGUI.format_time(int(entry.score)), entry.position + 1]
			return
	if page.is_last_page:
		_daily_status.text = "Not played yet today"
		return

	# Further down: look up just this player's entry, without a rank.
	var options := LeaderboardsAPI.GetEntriesOptions.new()
	options.alias_id = alias_id
	var mine: LeaderboardsAPI.EntriesPage = await Talo.leaderboards.get_entries(FinalScreen.TALO_LEADERBOARD, options)
	if request_id != _daily_request_id:
		return
	if mine == null or mine.entries.is_empty():
		_daily_status.text = "Not played yet today"
	else:
		_daily_status.text = "Your time: %s" % BoardGUI.format_time(int(mine.entries[0].score))


func _on_daily() -> void:
	# Ignore repeat presses while the date request is still pending.
	if _https.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
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

## Starts the daily challenge for [param date] (YYYY-MM-DD). The date is
## passed to the game only, never stored in [member GlobalState.board_seed],
## so the player's own settings (and the next PLAY) are left as they were.
func _start_daily(date: String) -> void:
	var daily: Dictionary = daily_settings(date)
	start_requested.emit(daily.board, daily.cols, daily.rows, daily.mine_perc, true, daily.seed, true)
