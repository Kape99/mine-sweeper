extends Node

@onready var main_menu = $GUI/Screen/MainMenu
@onready var board_gui: BoardGUI = $GUI/Screen/BoardGUI
@onready var start_button = $GUI/Screen/MainMenu/DiffiucltySelector/StartButton
@onready var camera: CameraController = $Camera
@onready var defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton

var triangle_board_scene = load("res://Scenes/Board/triangle_board.tscn")
var square_board_scene = load("res://Scenes/Board/square_board.tscn")
var hexagon_board_scene = load("res://Scenes/Board/hexagon_board.tscn")

var board: BaseBoard


func _ready():
	board_gui.connect("reset", reset)
	defuse_button.modulate = GlobaState.accent_color
	start_button.connect("pressed", _load_game)
	defuse_button.connect("toggled", _toggle_defuse)
	%BackToMenu.connect("pressed", reset)


func _game_finished(is_win: bool, time: float):
	$GUI/Screen/FinalScreen.visible = true


func _toggle_defuse(is_active):
	GlobaState._defusing = is_active


func _load_game():
	if GlobaState.selected_board == 0:
		board = triangle_board_scene.instantiate()
	elif GlobaState.selected_board == 1:
		board = square_board_scene.instantiate()
	elif GlobaState.selected_board == 2:
		board = hexagon_board_scene.instantiate()
	add_child(board)
	var game_data = GlobaState.get_game_data()

	GlobaState._defusing = false
	board.start_game(game_data.cols, game_data.rows, game_data.mines)
	board.connect("on_game_started", game_started)
	board.connect("on_defuse_changed", defused_changed)
	board.connect("on_game_finished", _game_finished)

	main_menu.visible = false
	# TODO fix reset the camera and limit the movement
	camera.set_limits(board.get_board_position(), board.get_board_size())


func defused_changed(defused: int):
	board_gui.defused_mines = defused


func game_started(mines: int):
	board_gui.visible = true
	board_gui.total_mines = mines


func reset():
	if board:
		board.free()
	main_menu.visible = true
	board_gui.visible = false
	$GUI/Screen/FinalScreen.visible = false
