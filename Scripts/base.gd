extends Node

@onready var main_menu = $GUI/Screen/MainMenu
@onready var board_gui: BoardGUI = $GUI/Screen/BoardGUI
@onready var start_button = $GUI/Screen/MainMenu/DifficultySelector/StartButton
@onready var camera: CameraController = $Camera
@onready var defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton

var triangle_board_scene = load("res://Scenes/Board/triangle_board.tscn")
var square_board_scene = load("res://Scenes/Board/square_board.tscn")
var hexagon_board_scene = load("res://Scenes/Board/hexagon_board.tscn")

var board: BaseBoard


func _ready():
	board_gui.reset.connect(reset)
	defuse_button.modulate = GlobalState.accent_color
	start_button.pressed.connect(_load_game)
	defuse_button.toggled.connect(_toggle_defuse)
	%BackToMenu.pressed.connect(reset)


func _game_finished(is_win: bool, time: float):
	if is_win:
		$GUI/Screen/FinalScreen/CenterContainer/VBoxContainer/MainTitle.text = "Good job!"
	else:
		$GUI/Screen/FinalScreen/CenterContainer/VBoxContainer/MainTitle.text = "Oh no!"
	board_gui.visible = false
	$GUI/Screen/FinalScreen.visible = true


func _toggle_defuse(is_active):
	GlobalState._defusing = is_active


func _load_game():
	var board_scenes = {0: triangle_board_scene, 1: square_board_scene, 2: hexagon_board_scene}
	board = board_scenes[GlobalState.selected_board].instantiate()
	add_child(board)
	var game_data = GlobalState.get_game_data()

	GlobalState._defusing = false
	defuse_button.button_pressed = false
	board.start_game(game_data.cols, game_data.rows, game_data.mines)
	board.on_game_started.connect(game_started)
	board.on_defuse_changed.connect(defused_changed)
	board.on_game_finished.connect(_game_finished)

	main_menu.visible = false
	camera.reset_view()


func defused_changed(defused: int):
	board_gui.defused_mines = defused


func game_started(mines: int):
	board_gui.visible = true
	board_gui.total_mines = mines


func reset():
	if board:
		board.free()
	GlobalState._defusing = false
	defuse_button.button_pressed = false
	main_menu.visible = true
	board_gui.visible = false
	$GUI/Screen/FinalScreen.visible = false
