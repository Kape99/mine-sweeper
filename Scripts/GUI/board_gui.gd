class_name BoardGUI extends Control

@onready var _score_box: Control = $ColorRect/ScoreBox
@onready var _score_tracker: Label = $ColorRect/ScoreBox/ScoreTracker

signal reset

var total_mines: int:
	set(value):
		total_mines = value
		defused_mines = 0
		_update_score()

var defused_mines: int:
	set(value):
		defused_mines = value
		_update_score()


func _ready():
	$ColorRect.color = GlobaState.accent_color
	_score_box.modulate = GlobaState.background_color


func _update_score():
	_score_tracker.text = str(defused_mines) + "/" + str(total_mines)


func _on_reset_pressed():
	emit_signal("reset")
