extends Node

@onready var board = $TriangleBoard
@onready var main_menu = $GUI/Screen/MainMenu
@onready var start_button = $GUI/Screen/MainMenu/VBoxContainer/StartButton
@onready var camera: CameraController = $Camera


func _ready():
	start_button.connect("pressed", load_game)


func load_game():
	board.start_game(17, 14, 20)
	# TODO animation
	main_menu.visible = false
	board.visible = true

	var b_size = board.get_board_size()
	camera.set_limits(board.size / 2, b_size / 2)
