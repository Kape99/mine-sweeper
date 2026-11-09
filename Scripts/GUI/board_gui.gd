## In-game HUD displaying the defused mines counter, the game timer, and
## a reset button.
class_name BoardGUI
extends Control

@onready var _score_box: Control = $ColorRect/ScoreBox
@onready var _score_tracker: Label = $ColorRect/ScoreBox/ScoreTracker
@onready var _timer_label: Label = $ColorRect/ScoreBox/TimerLabel

## Emitted when the player presses the reset button.
signal reset

## Emitted when the player presses the pause button.
signal pause_requested

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


## Millisecond timestamp when the current game started (see
## [method start_timer]).
var _timer_start_msec: int = 0

## Whether the game timer is counting.
var _timer_running: bool = false

## Timer value frozen at [method stop_timer] (seconds).
var _elapsed_seconds: int = 0


func _ready() -> void:
	$ColorRect.color = GlobalState.scheme.accent
	# Set the text color directly: the UI theme gives labels a dark font
	# color, so tinting with modulate could only ever darken it.
	_score_box.modulate = Color.WHITE
	for label: Label in [_score_tracker, _timer_label]:
		label.add_theme_color_override("font_color", GlobalState.scheme.hud_text)
	$ColorRect/ScoreBox/MineIcon.modulate = GlobalState.scheme.hud_text


func _process(_delta: float) -> void:
	if _timer_running:
		_update_timer()


## Starts the game timer from zero. Called when the game starts.
func start_timer() -> void:
	_timer_start_msec = Time.get_ticks_msec()
	_elapsed_seconds = 0
	_timer_running = true
	_update_timer()


## Stops the game timer (game over), freezing the displayed time.
func stop_timer() -> void:
	_elapsed_seconds = elapsed_seconds()
	_timer_running = false


## Seconds on the game timer: live while running, frozen once stopped.
func elapsed_seconds() -> int:
	if _timer_running:
		return (Time.get_ticks_msec() - _timer_start_msec) / 1000
	return _elapsed_seconds


## Formats [param total_seconds] as M:SS (timer and end-screen recap).
static func format_time(total_seconds: int) -> String:
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


func _update_timer() -> void:
	_timer_label.text = format_time(elapsed_seconds())


func _update_score() -> void:
	_score_tracker.text = "%d/%d" % [defused_mines, total_mines]


func _on_reset_pressed() -> void:
	reset.emit()


func _on_pause_pressed() -> void:
	pause_requested.emit()
