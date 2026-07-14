## Scrollable difficulty and board-type selector on the main menu.
## Animates transitions between options using [AnimationPlayer] nodes.
class_name DifficultySelector
extends Control

## Current difficulty index (0 = Easy, 1 = Medium, 2 = Hard). Synced to [GlobalState].
var selected_difficulty: int = 1:
	set(value):
		selected_difficulty = value
		GlobalState.selected_difficulty = value

## Current board type index (0 = Triangle, 1 = Square, 2 = Hexagon). Synced to [GlobalState].
var selected_board: int = 1:
	set(value):
		selected_board = value
		GlobalState.selected_board = value

## Display labels for each difficulty level.
var _display_difficulty: Array[String] = ["Easy", "Medium", "Hard"]

## Icons for each board type, loaded at ready time.
@onready var _display_board: Array[Texture2D] = [
	preload("res://Asset/Icons/triangle_border.svg"),
	preload("res://Asset/Icons/square_border.svg"),
	preload("res://Asset/Icons/hexagon_border.svg"),
]

@onready var _left_label: Label = $Difficulty
@onready var _right_label: Label = $DifficultyFake
@onready var _up_icon: TextureRect = $BoardIcon
@onready var _down_icon: TextureRect = $BoardIcon2

@onready var _left_button: TextureButton = $LeftDifficulty
@onready var _right_button: TextureButton = $RightDifficulty
@onready var _up_button: TextureButton = $BoardTypeUp
@onready var _down_button: TextureButton = $BoardTypeDown

@onready var _text_animation: AnimationPlayer = $TextAnimation
@onready var _icon_animation: AnimationPlayer = $IconAnimation

var _is_text_animating: bool = false
var _is_icon_animating: bool = false


func _ready() -> void:
	modulate = GlobalState.accent_color

	_left_button.pressed.connect(_scroll_left)
	_right_button.pressed.connect(_scroll_right)
	_up_button.pressed.connect(_scroll_up)
	_down_button.pressed.connect(_scroll_down)
	_text_animation.animation_finished.connect(_on_text_animation_finished)
	_icon_animation.animation_finished.connect(_on_icon_animation_finished)

	_left_label.text = _display_difficulty[selected_difficulty]
	_right_label.text = _display_difficulty[selected_difficulty]
	_up_icon.texture = _display_board[selected_board]
	_down_icon.texture = _display_board[selected_board]


# -- Difficulty scrolling ------------------------------------------------------

func _scroll_left() -> void:
	if _is_text_animating:
		return
	_left_label.text = _display_difficulty[selected_difficulty]
	selected_difficulty = (selected_difficulty - 1 + _display_difficulty.size()) % _display_difficulty.size()
	_right_label.text = _display_difficulty[selected_difficulty]
	_text_animation.play("scroll")
	_is_text_animating = true


func _scroll_right() -> void:
	if _is_text_animating:
		return
	_is_text_animating = true
	_right_label.text = _display_difficulty[selected_difficulty]
	selected_difficulty = (selected_difficulty + 1) % _display_difficulty.size()
	_left_label.text = _display_difficulty[selected_difficulty]
	_text_animation.play_backwards("scroll")


# -- Board type scrolling ------------------------------------------------------

func _scroll_up() -> void:
	if _is_icon_animating:
		return
	_is_icon_animating = true
	_up_icon.texture = _display_board[selected_board]
	selected_board = (selected_board - 1 + _display_board.size()) % _display_board.size()
	_down_icon.texture = _display_board[selected_board]
	_icon_animation.play("scroll_board")


func _scroll_down() -> void:
	if _is_icon_animating:
		return
	_is_icon_animating = true
	_down_icon.texture = _display_board[selected_board]
	selected_board = (selected_board + 1) % _display_board.size()
	_up_icon.texture = _display_board[selected_board]
	_icon_animation.play_backwards("scroll_board")


# -- Animation callbacks -------------------------------------------------------

func _on_text_animation_finished(anim_name: StringName) -> void:
	if anim_name == "scroll":
		_is_text_animating = false
		_left_label.text = _display_difficulty[selected_difficulty]
		_right_label.text = _display_difficulty[selected_difficulty]


func _on_icon_animation_finished(anim_name: StringName) -> void:
	if anim_name == "scroll_board":
		_is_icon_animating = false
		_up_icon.texture = _display_board[selected_board]
		_down_icon.texture = _display_board[selected_board]
