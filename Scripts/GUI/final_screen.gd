extends Control

@onready var _final_title: Label = $BlurPanel/CenterContainer/VBoxContainer/MainTitle
@onready var _final_recap: Label = $BlurPanel/CenterContainer/VBoxContainer/RecapLabel
@onready var _leaderboard_box: BoxContainer = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard
@onready var _score_button: Button = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard/ScoreButton
@onready var _leaderboard_scroll: ScrollContainer = $BlurPanel/CenterContainer/VBoxContainer/ScrollContainer
@onready var _leaderboard: VBoxContainer = $BlurPanel/CenterContainer/VBoxContainer/ScrollContainer/Leaderboard

@export var _entry: PackedScene

## Emitted when the player presses the reset button.
signal reset

## Emitted when the player presses Continue after losing a daily challenge.
signal continue_requested

## Emitted when a logged-out player wants to send a daily score: the
## Account screen opens on top, and the button updates once they log in.
signal login_requested

const TALO_LEADERBOARD : String = "daily"
var time = 0;

## Whether this game's score was already sent (one submission per win).
var _score_sent: bool = false

func _ready() -> void:
	%BackToMenu.pressed.connect(_reset)
	%Continue.pressed.connect(continue_requested.emit)
	_score_button.pressed.connect(_on_score_button_pressed)
	Talo.players.identified.connect(func(_alias: TaloPlayerAlias) -> void: _update_score_button())
	$BlurPanel.gui_input.connect(_on_panel_gui_input)

## Wheel and pan-gesture events pass through MOUSE_FILTER_STOP controls
## unless one accepts them (that's how nested scroll areas work). The
## leaderboard stops accepting them once it reaches its end, so without
## this they'd fall through to the camera and zoom the board behind.
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventGesture:
		accept_event()

## Shows the result of a game. Only the daily challenge has a leaderboard:
## its entries are shown win or lose, but a score can only be submitted
## after a win. A lost daily can be continued: retried until it's won.
func game_finished(is_win: bool, _time: int, _mines: int, _defused: int, is_daily: bool = false) -> void:
	time = _time
	_score_sent = false
	_update_score_button()
	_final_title.text = "Good job!" if is_win else "Oh no!"
	var time_text: String = BoardGUI.format_time(_time)
	%Continue.visible = is_daily and not is_win
	_leaderboard_box.visible = is_daily and is_win
	_leaderboard_scroll.visible = is_daily
	if is_win:
		_final_recap.text = "All %d mines found in %s" % [_mines, time_text]
	else:
		_final_recap.text = "%d of %d mines found in %s" % [_defused, _mines, time_text]
	if is_daily:
		_refresh_leaderboard()

func _reset() -> void:
	reset.emit()

## Scores are sent as the logged-in Talo account, so nobody can post under
## someone else's name. Logged-out players are sent to log in first.
func _on_score_button_pressed() -> void:
	if not AccountMenu.is_logged_in():
		login_requested.emit()
		return
	_score_button.disabled = true
	_score_button.text = "Sending..."
	var res: LeaderboardsAPI.AddEntryResult = await Talo.leaderboards.add_entry(TALO_LEADERBOARD, time)
	_score_sent = res.success
	_update_score_button()
	if not res.success:
		_score_button.text = "Couldn't send, try again"
		return
	_refresh_leaderboard()


func _update_score_button() -> void:
	_score_button.disabled = _score_sent
	if _score_sent:
		_score_button.text = "Score sent"
	elif AccountMenu.is_logged_in():
		_score_button.text = "Send score as %s" % AccountMenu.player_name()
	else:
		_score_button.text = "Log in to send score"

func _refresh_leaderboard() -> void:
	# Drop the previous game's rows (and the scene's placeholder row) first.
	for child in _leaderboard.get_children():
		child.queue_free()

	var leaderboard = await Talo.leaderboards.get_entries(TALO_LEADERBOARD)
	if leaderboard == null:  # offline or request failed
		return

	for result in leaderboard.entries:
		var entry_instance: Entry = _entry.instantiate()
		_leaderboard.add_child(entry_instance)
		var player_id: String = result.player_alias.identifier if result.player_alias else "Unknown"
		var score: String = str(int(result.score))
		entry_instance.set_entry(player_id, score)
