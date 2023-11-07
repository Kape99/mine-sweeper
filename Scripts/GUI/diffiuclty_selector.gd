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

@onready var left_label: Label = $Difficulty
@onready var right_label: Label = $DifficultyFake
@onready var up_icon: TextureRect = $BoardIcon
@onready var down_icon: TextureRect = $BoardIcon2

@onready var left_button: TextureButton = $LeftDifficulty
@onready var right_button: TextureButton = $RightDifficulty
@onready var up_button: TextureButton = $BoardTypeUp
@onready var down_button: TextureButton = $BoardTypeDown

@onready var text_animation_player = $TextAnimation
@onready var icon_animation_player = $IconAnimation

var is_text_animating = false
var is_icon_animating = false


func _ready():
	left_button.connect("pressed", _scroll_left)
	right_button.connect("pressed", _scroll_right)
	up_button.connect("pressed", _scroll_up)
	down_button.connect("pressed", _scroll_down)
	text_animation_player.connect("animation_finished", _text_animation_finished)
	icon_animation_player.connect("animation_finished", _icon_animation_finished)
	left_label.text = display_difficulty[selected_difficulty]
	right_label.text = display_difficulty[selected_difficulty]
	up_icon.texture = display_board[selected_board]
	down_icon.texture = display_board[selected_board]


func _scroll_left():
	if not is_text_animating:
		left_label.text = display_difficulty[selected_difficulty]
		selected_difficulty -= 1
		selected_difficulty %= display_difficulty.size()
		right_label.text = display_difficulty[selected_difficulty]
		text_animation_player.play("scroll")
		is_text_animating = true


func _scroll_right():
	if not is_text_animating:
		is_text_animating = true
		right_label.text = display_difficulty[selected_difficulty]
		selected_difficulty += 1
		selected_difficulty %= display_difficulty.size()
		left_label.text = display_difficulty[selected_difficulty]
		text_animation_player.play_backwards("scroll")


func _scroll_up():
	if not is_icon_animating:
		is_icon_animating = true
		up_icon.texture = display_board[selected_board]
		selected_board -= 1
		selected_board %= display_board.size()
		down_icon.texture = display_board[selected_board]
		icon_animation_player.play("scroll_board")


func _scroll_down():
	if not is_icon_animating:
		is_icon_animating = true
		down_icon.texture = display_board[selected_board]
		selected_board += 1
		selected_board %= display_board.size()
		up_icon.texture = display_board[selected_board]
		icon_animation_player.play_backwards("scroll_board")


func _text_animation_finished(name):
	if name == "scroll":
		is_text_animating = false
		left_label.text = display_difficulty[selected_difficulty]
		right_label.text = display_difficulty[selected_difficulty]


func _icon_animation_finished(name):
	if name == "scroll_board":
		is_icon_animating = false
		up_icon.texture = display_board[selected_board]
		down_icon.texture = display_board[selected_board]
