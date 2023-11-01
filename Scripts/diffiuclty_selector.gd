class_name DifficultySelector extends Node

var selected_difficulty = 1:
	set(value):
		selected_difficulty = value
		GlobaState.selected_difficulty = value

var selected_board = 1:
	set(value):
		selected_board = value
		GlobaState.selected_board = value

var display_difficulty: Array = ["Easy", "Medium", "Hard"]
@onready var display_board: Array = [
	preload("res://Asset/Icons/triangle_border.svg"),
	preload("res://Asset/Icons/square_border.svg"),
	preload("res://Asset/Icons/hexagon_border.svg")
]

@onready var difficulty_label: Label = $Difficulty
@onready var animation_label: Label = $DifficultyFake
@onready var board_icon: TextureRect = $BoardIcon
@onready var board_icon2: TextureRect = $BoardIcon2

@onready var left_button: TextureButton = $LeftDifficulty
@onready var right_button: TextureButton = $RightDifficulty
@onready var up_button: TextureButton = $BoardTypeUp
@onready var down_button: TextureButton = $BoardTypeDown

@onready var animation_player = $Animation

var is_animating = false
var is_animating_board = false


func _ready():
	left_button.connect("pressed", _scroll_left)
	right_button.connect("pressed", _scroll_right)
	up_button.connect("pressed", _scroll_up)
	down_button.connect("pressed", _scroll_down)
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


func _scroll_up():
	if not is_animating_board:
		board_icon.texture = display_board[selected_board]
		selected_board -= 1
		selected_board %= display_board.size()
		board_icon2.texture = display_board[selected_board]
		animation_player.play("scroll_board")
		is_animating_board = true


func _scroll_down():
	if not is_animating_board:
		board_icon2.texture = display_board[selected_board]
		selected_board += 1
		selected_board %= display_board.size()
		board_icon.texture = display_board[selected_board]
		animation_player.play_backwards("scroll_board")
		is_animating_board = true


func _animation_finished(name):
	if name == "scroll":
		is_animating = false
		difficulty_label.text = display_difficulty[selected_difficulty]
	if name == "scroll_board":
		is_animating_board = false
		board_icon.texture = display_board[selected_board]
