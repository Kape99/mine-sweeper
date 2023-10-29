class_name DifficultySelector extends Node

var selected_difficulty = 1:
	set(value):
		selected_difficulty = value
		GlobaState.selected_difficulty = value
var display_difficulty: Array = ["Easy", "Medium", "Hard"]

@onready var difficulty_label: Label = $Difficulty
@onready var animation_label: Label = $DifficultyFake

@onready var left_button: TextureButton = $LeftDifficulty
@onready var right_button: TextureButton = $RightDifficulty

@onready var animation_player = $Animation

var is_animating = false


func _ready():
	left_button.connect("pressed", _scroll_left)
	right_button.connect("pressed", _scroll_right)
	animation_player.connect("animation_finished", _animation_finished)
	difficulty_label.text = display_difficulty[selected_difficulty]
	animation_label.text = display_difficulty[selected_difficulty]


func _scroll_left():
	if not is_animating:
		animation_label.text = display_difficulty[selected_difficulty]
		selected_difficulty -= 1
		selected_difficulty %= display_difficulty.size()
		animation_label.text = display_difficulty[selected_difficulty]
		animation_player.play("scroll")
		is_animating = true


func _scroll_right():
	if not is_animating:
		animation_label.text = display_difficulty[selected_difficulty]
		selected_difficulty += 1
		selected_difficulty %= display_difficulty.size()
		difficulty_label.text = display_difficulty[selected_difficulty]

		animation_player.play_backwards("scroll")
		is_animating = true


func _animation_finished(name):
	if name == "scroll":
		is_animating = false
		difficulty_label.text = display_difficulty[selected_difficulty]
