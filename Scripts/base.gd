extends Node

@onready var main_menu = $GUI/Screen/MainMenu
@onready var board_gui = $GUI/Screen/BoardGUI
@onready var start_button = $GUI/Screen/MainMenu/DiffiucltySelector/StartButton
@onready var camera: CameraController = $Camera
@onready var defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton

var triangle_board_scene = load("res://Scenes/Board/triangle_board.tscn")
var square_board_scene = load("res://Scenes/Board/square_board.tscn")
var hexagon_board_scene = load("res://Scenes/Board/hexagon_board.tscn")

var board: BaseBoard


func _ready():
	start_button.connect("pressed", _load_game)
	defuse_button.connect("toggled", _toggle_defuse)
	%BackToMenu.connect("pressed", _on_button_pressed)


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

	board.start_game(game_data.cols, game_data.rows, game_data.mines)

	main_menu.visible = false
	board_gui.visible = true

	# TODO fix reset the camera and limit the movement
	camera.set_limits(board.get_board_position(), board.get_board_size())


func _on_button_pressed():
	board.free()

	main_menu.visible = true

	board_gui.visible = false
	$GUI/Screen/FinalScreen.visible = false
