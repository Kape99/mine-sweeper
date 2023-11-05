extends Node

@onready var triangle_board = $TriangleBoard
@onready var sqare_board = $SquareBoard
@onready var hexagon_board = $HexagonBoard

@onready var main_menu = $GUI/Screen/MainMenu
@onready var board_gui = $GUI/Screen/BoardGUI
@onready var start_button = $GUI/Screen/MainMenu/DiffiucltySelector/StartButton
@onready var camera: CameraController = $Camera
@onready var defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton


func _ready():
	start_button.connect("pressed", _load_game)
	defuse_button.connect("toggled", _toggle_defuse)
	triangle_board.connect("game_finished", _game_finished)
	sqare_board.connect("game_finished", _game_finished)
	hexagon_board.connect("game_finished", _game_finished)
	%BackToMenu.connect("pressed", _on_button_pressed)


func _game_finished(is_win: bool, time: float):
	$GUI/Screen/FinalScreen.visible = true


func _toggle_defuse(is_active):
	GlobaState._defusing = is_active


func _load_game():
	if GlobaState.selected_board == 0:
		triangle_board.start_game(GlobaState.get_cols(), GlobaState.get_rows(), GlobaState.get_mines())
		triangle_board.visible = true
	elif GlobaState.selected_board == 1:
		sqare_board.start_game(GlobaState.get_cols(), GlobaState.get_rows(), GlobaState.get_mines())
		sqare_board.visible = true
	elif GlobaState.selected_board == 2:
		hexagon_board.start_game(GlobaState.get_cols(), GlobaState.get_rows(), GlobaState.get_mines())
		hexagon_board.visible = true
	main_menu.visible = false
	board_gui.visible = true


#	place camera


func _on_button_pressed():
	triangle_board.clear()
	sqare_board.clear()
	hexagon_board.clear()
	main_menu.visible = true
	triangle_board.visible = false
	sqare_board.visible = false
	hexagon_board.visible = false
	board_gui.visible = false
	$GUI/Screen/FinalScreen.visible = false
