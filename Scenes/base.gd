extends Node

@onready var board = $TriangleBoard
@onready var main_menu = $GUI/Screen/MainMenu
@onready var board_gui = $GUI/Screen/BoardGUI
@onready var start_button = $GUI/Screen/MainMenu/VBoxContainer/StartButton
@onready var camera: CameraController = $Camera
@onready var defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton


func _ready():
	start_button.connect("pressed", _load_game)
	defuse_button.connect("toggled", _toggle_defuse)


func _toggle_defuse(is_active):
	GlobaState._defusing = is_active


func _load_game():
	board.start_game(GlobaState.get_cols(), GlobaState.get_rows(), GlobaState.get_mines())
	# TODO animation
	main_menu.visible = false
	board.visible = true
	board_gui.visible = true

	var b_size = board.get_board_size()
	camera.set_limits(board.size / 2, b_size / 2)


func _on_button_pressed():
	board.clear()
	main_menu.visible = true
	board.visible = false
	board_gui.visible = false
