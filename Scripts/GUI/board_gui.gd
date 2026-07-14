## In-game HUD displaying the defused mines counter and a reset button.
class_name BoardGUI
extends Control

@onready var _score_box: Control = $ColorRect/ScoreBox
@onready var _score_tracker: Label = $ColorRect/ScoreBox/ScoreTracker

## Emitted when the player presses the reset button.
signal reset

## Total number of mines on the board. Setting this resets [member defused_mines] to 0.
var total_mines: int:
	set(value):
		total_mines = value
		defused_mines = 0
		_update_score()

## Number of mines the player has flagged so far.
var defused_mines: int:
	set(value):
		defused_mines = value
		_update_score()


func _ready() -> void:
	$ColorRect.color = GlobalState.accent_color
	_score_box.modulate = GlobalState.background_color


func _update_score() -> void:
	_score_tracker.text = "%d/%d" % [defused_mines, total_mines]


func _on_reset_pressed() -> void:
	reset.emit()
