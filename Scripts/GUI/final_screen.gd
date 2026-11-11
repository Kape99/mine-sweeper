extends Control

@onready var _final_title: Label = $BlurPanel/CenterContainer/VBoxContainer/MainTitle
@onready var _final_recap: Label = $BlurPanel/CenterContainer/VBoxContainer/RecapLabel
@onready var _leaderboard_box: BoxContainer = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard
@onready var _player_edit: TextEdit = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard/Username
@onready var _score_button: Button = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard/ScoreButton
@onready var _leaderboard_scroll: ScrollContainer = $BlurPanel/CenterContainer/VBoxContainer/ScrollContainer
@onready var _leaderboard: VBoxContainer = $BlurPanel/CenterContainer/VBoxContainer/ScrollContainer/Leaderboard

@export var _entry: PackedScene

## Emitted when the player presses the reset button.
signal reset

## Emitted when the player presses Continue after losing a daily challenge.
signal continue_requested

const TALO_SERVICE : String = "username"
const TALO_LEADERBOARD : String = "daily"
var time = 0;

func _ready() -> void:
	%BackToMenu.pressed.connect(_reset)
	%Continue.pressed.connect(continue_requested.emit)
	_score_button.pressed.connect(_submit_score)
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

func _submit_score() -> void:
	await Talo.players.identify(TALO_SERVICE, _player_edit.text)
	await Talo.leaderboards.add_entry(TALO_LEADERBOARD, time)
	_refresh_leaderboard()

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
