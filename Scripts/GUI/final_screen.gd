extends Control

@onready var _final_title: Label = $BlurPanel/CenterContainer/VBoxContainer/MainTitle
@onready var _final_recap: Label = $BlurPanel/CenterContainer/VBoxContainer/RecapLabel
@onready var _leaderboard_box: BoxContainer = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard
@onready var _player_edit: TextEdit = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard/Username
@onready var _score_button: Button = $BlurPanel/CenterContainer/VBoxContainer/LeaderBoard/ScoreButton
@onready var _leaderboard: VBoxContainer = $BlurPanel/CenterContainer/VBoxContainer/ScrollContainer/Leaderboard

@export var _entry: PackedScene

## Emitted when the player presses the reset button.
signal reset

const TALO_SERVICE : String = "username"
const TALO_LEADERBOARD : String = "daily"
var time = 0;

func _ready() -> void:
	%BackToMenu.pressed.connect(_reset)
	_score_button.pressed.connect(_show_leaderboard)

func game_finished(is_win: bool, _time: int, _mines: int, _defused: int) -> void:
	time = _time
	_final_title.text = "Good job!" if is_win else "Oh no!"
	var time_text: String = BoardGUI.format_time(_time)
	_leaderboard_box.visible = true
	if is_win:
		_final_recap.text = "All %d mines found in %s" % [_mines, time_text]
	else:
		_final_recap.text = "%d of %d mines found in %s" % [_defused, _mines, time_text]

func _reset() -> void:
	reset.emit()

func _show_leaderboard() -> void:
	var res := await Talo.players.identify(TALO_SERVICE, _player_edit.text)
	var res2 := await Talo.leaderboards.add_entry(TALO_LEADERBOARD, time)

	var leaderboard = await Talo.leaderboards.get_entries(TALO_LEADERBOARD)

	# Clear existing entries
	for child in _leaderboard.get_children():
		child.queue_free()

	for result in leaderboard.entries:
		var entry_instance: Entry = _entry.instantiate()
		_leaderboard.add_child(entry_instance)
		var player_id: String = result.player_alias.identifier if result.player_alias else "Unknown"
		var score: String = str(int(result.score))
		entry_instance.set_entry(player_id, score)


	
