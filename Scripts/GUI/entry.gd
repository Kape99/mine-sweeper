class_name Entry
extends HBoxContainer

@onready var _player_label : Label = $PlayerID
@onready var _score_label : Label = $Score

func set_entry(player_id: String, score: String) -> void:
	_player_label.text = player_id
	var time : int = score.to_int()
	var minutes : int = time / 60
	var seconds : int = time % 60
	_score_label.text = "%d:%02d" % [minutes, seconds]
