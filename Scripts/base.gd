## Main game controller. Manages screen flow (main menu → gameplay → result screen),
## board instantiation, and signal wiring between the board and UI.
## Periodically refreshes board tiles to follow the camera for infinite scrolling.
extends Node

@onready var _main_menu: VBoxContainer = $GUI/Screen/VBoxContainer
@onready var _board_gui: BoardGUI = $GUI/Screen/BoardGUI
@onready var _start_button: TextureButton = $GUI/Screen/VBoxContainer/MainMenu/DifficultySelector/StartButton
@onready var _camera: CameraController = $Camera
@onready var _defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton
@onready var _final_screen: ColorRect = $GUI/Screen/FinalScreen
@onready var _final_title: Label = $GUI/Screen/FinalScreen/CenterContainer/VBoxContainer/MainTitle

var _triangle_board_scene: PackedScene = load("res://Scenes/Board/triangle_board.tscn")
var _square_board_scene: PackedScene = load("res://Scenes/Board/square_board.tscn")
var _hexagon_board_scene: PackedScene = load("res://Scenes/Board/hexagon_board.tscn")

## Maps board type index to its scene resource.
var _board_scenes: Dictionary = {}

## Currently active board instance, or [code]null[/code] if none.
var _board: BaseBoard


func _ready() -> void:
	_board_scenes = {
		0: _triangle_board_scene,
		1: _square_board_scene,
		2: _hexagon_board_scene,
	}
	_board_gui.reset.connect(_reset)
	_defuse_button.modulate = GlobalState.accent_color
	_start_button.pressed.connect(_load_game)
	_defuse_button.toggled.connect(_toggle_defuse)
	%BackToMenu.pressed.connect(_reset)


func _process(_delta: float) -> void:
	if _board and _board.get_child_count() > 0:
		_board.recenter_if_needed(_camera.offset)


func _game_finished(is_win: bool, _time: float) -> void:
	_final_title.text = "Good job!" if is_win else "Oh no!"
	_board_gui.visible = false
	_final_screen.visible = true


func _toggle_defuse(is_active: bool) -> void:
	GlobalState.is_defusing = is_active


## Instantiates the selected board, starts a new game, and switches to gameplay view.
func _load_game() -> void:
	_board = _board_scenes[GlobalState.selected_board].instantiate()
	add_child(_board)
	var game_data: GlobalState.GameData = GlobalState.get_game_data()

	GlobalState.is_defusing = false
	_defuse_button.button_pressed = false
	_board.start_game(game_data.cols, game_data.rows, game_data.mines)
	_board.on_game_started.connect(_game_started)
	_board.on_defuse_changed.connect(_defused_changed)
	_board.on_game_finished.connect(_game_finished)

	_main_menu.visible = false
	# Center camera on the board
	_camera.offset = _board.get_board_size() / 2.0


func _defused_changed(defused: int) -> void:
	_board_gui.defused_mines = defused


func _game_started(mine_count: int) -> void:
	_board_gui.visible = true
	_board_gui.total_mines = mine_count


## Returns to the main menu, freeing the current board.
func _reset() -> void:
	if _board:
		_board.free()
	GlobalState.is_defusing = false
	_defuse_button.button_pressed = false
	_main_menu.visible = true
	_board_gui.visible = false
	_final_screen.visible = false


func _on_no_border_toggled(toggled_on: bool) -> void:
	GlobalState.no_border = toggled_on