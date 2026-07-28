## Main game controller. Manages screen flow (main menu → gameplay → result screen),
## board instantiation, and signal wiring between the board and UI.
## Periodically refreshes board tiles to follow the camera for infinite scrolling.
extends Node

@onready var _main_menu: MainMenu = $GUI/Screen/MainMenu
@onready var _board_gui: BoardGUI = $GUI/Screen/BoardGUI
@onready var _camera: CameraController = $Camera
@onready var _defuse_button: TextureButton = $GUI/Screen/BoardGUI/DefuseButton
@onready var _final_screen: Control = $GUI/Screen/FinalScreen
@onready var _final_title: Label = $GUI/Screen/FinalScreen/BlurPanel/CenterContainer/VBoxContainer/MainTitle

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
	_board_gui.pause_requested.connect(_on_pause_requested)
	_defuse_button.modulate = GlobalState.accent_color
	_defuse_button.toggled.connect(_toggle_defuse)

	# Connect to the fresh MainMenu's intent signals.
	_main_menu.start_requested.connect(_load_game)
	_main_menu.settings_requested.connect(_on_settings_pressed)
	_main_menu.quit_requested.connect(_on_quit)
	_main_menu.no_border_toggled.connect(_on_no_border_toggled)
	_main_menu.wrap_mode_changed.connect(_on_wrap_mode_changed)

	%BackToMenu.pressed.connect(_reset)

	# Show the main menu through ScreenManager so Settings can hide it
	# in-place and restore it on back.
	var sm: ScreenManager = $ScreenManager
	sm.show_main_menu(_main_menu)


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
	var mine_count: int = GlobalState.get_mine_count()

	GlobalState.is_defusing = false
	_defuse_button.button_pressed = false
	_board.start_game(GlobalState.board_cols, GlobalState.board_rows, mine_count, GlobalState.board_wrap)
	_board.on_game_started.connect(_game_started)
	_board.on_defuse_changed.connect(_defused_changed)
	_board.on_game_finished.connect(_game_finished)

	_main_menu.visible = false
	# Center camera on the board and configure bounds based on mode.
	if GlobalState.board_wrap:
		_camera.offset = _board.get_board_size() / 2.0
		_camera.reset_view()  # clears any stale bounds from a previous game
		_camera.offset = _board.get_board_size() / 2.0  # re-center after reset
	else:
		_camera.set_board_bounds(_board.get_board_position(), _board.get_board_size())


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
	_board_gui.visible = false
	_final_screen.visible = false

	# Return to main menu through ScreenManager so overlays are cleared.
	var sm: ScreenManager = $ScreenManager
	sm.show_main_menu(_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_BACK:
				_handle_back_button()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				if _board and _board.get_child_count() > 0:
					_defuse_button.button_pressed = not _defuse_button.button_pressed
					get_viewport().set_input_as_handled()


func _handle_back_button() -> void:
	var sm: ScreenManager = $ScreenManager
	if _board and _board.get_child_count() > 0:
		# Gameplay is active — toggle pause
		if sm._current and sm._current is PauseOverlay:
			sm.hide_pause(_board)
		else:
			sm.show_pause(_board)
	# If no game is active (main menu), back button does nothing.


func _on_pause_requested() -> void:
	if _board:
		$ScreenManager.show_pause(_board)


func _on_settings_pressed() -> void:
	var sm: ScreenManager = $ScreenManager
	sm.push(
		load("res://Scenes/Menu/SettingsMenu.tscn").instantiate(),
		true,
		false  # dismiss_current=false — keep MainMenu alive behind Settings
	)


func _on_quit() -> void:
	get_tree().quit()


func _on_no_border_toggled(toggled_on: bool) -> void:
	GlobalState.no_border = toggled_on


func _on_wrap_mode_changed(wrap: bool) -> void:
	pass  # Setting is already updated in GlobalState by MainMenu; board picks it up on next game start.
