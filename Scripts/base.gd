## Main game controller. Manages screen flow (main menu → gameplay → result screen),
## board instantiation, and signal wiring between the board and UI.
## Periodically refreshes board tiles to follow the camera for infinite scrolling.
## While no game is running, builds the next board in the background so
## Start is instant (see [method _prepare_board_step]).
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

## Time budget per frame for building the next board in the background.
const PREPARE_BUDGET_USEC: int = 4000

## How long the menu settings must stay unchanged before a background
## build (re)starts, so stepping a SpinBox doesn't restart it every click.
const PREPARE_SETTLE_MSEC: int = 300

## Board being built in the background while no game is running, for the
## menu's current settings, so Start doesn't have to build thousands of
## cells in one frame. Fully transparent and paused until a game uses it.
## (Transparent rather than hidden: a hidden board defers its layout and
## drawing to the moment it's shown, which is exactly the cost to avoid.)
var _prepared_board: BaseBoard = null

## The settings [member _prepared_board] was built for (see
## [method _get_prepare_key]).
var _prepared_key: Array = []

## Latest settings seen while preparing, and when they last changed.
var _pending_key: Array = []
var _pending_key_since: int = 0


func _ready() -> void:
	_board_scenes = {
		0: _triangle_board_scene,
		1: _square_board_scene,
		2: _hexagon_board_scene,
	}
	# Clean up static cell pools on exit so off-tree pooled nodes don't leak RIDs.
	get_tree().root.tree_exiting.connect(BaseBoard.clear_pools)
	_camera.reset_view()

	_board_gui.reset.connect(_reset)
	_board_gui.pause_requested.connect(_on_pause_requested)
	_defuse_button.modulate = GlobalState.accent_color
	_defuse_button.toggled.connect(_toggle_defuse)

	# Connect to the fresh MainMenu's intent signals.
	_main_menu.start_requested.connect(_load_game)
	_main_menu.settings_requested.connect(_on_settings_pressed)
	_main_menu.quit_requested.connect(_on_quit)
	_main_menu.wrap_mode_changed.connect(_on_wrap_mode_changed)

	%BackToMenu.pressed.connect(_reset)

	# Show the main menu through ScreenManager so Settings can hide it
	# in-place and restore it on back.
	var sm: ScreenManager = $ScreenManager
	sm.show_main_menu(_main_menu)


func _process(_delta: float) -> void:
	if _board:
		if _board.get_child_count() > 0:
			_board.recenter_if_needed(_camera.offset)
	else:
		_prepare_board_step()


## Everything a freshly built board depends on. Cell colors are set when
## cells are created, so the color scheme is part of it.
func _get_prepare_key() -> Array:
	return [
		GlobalState.selected_board,
		GlobalState.board_cols,
		GlobalState.board_rows,
		GlobalState.board_wrap,
		GlobalState.selected_scheme,
	]


## Advances the background build of the next board by one frame's budget.
func _prepare_board_step() -> void:
	var key: Array = _get_prepare_key()
	var now: int = Time.get_ticks_msec()
	if key != _pending_key:
		_pending_key = key
		_pending_key_since = now
	if now - _pending_key_since < PREPARE_SETTLE_MSEC:
		return

	if _prepared_board and key != _prepared_key:
		if key[0] != _prepared_key[0]:
			_discard_prepared_board()  # different board shape: different scene
		else:
			_prepared_board.prepare(GlobalState.board_cols, GlobalState.board_rows, GlobalState.board_wrap)
			_prepared_key = key
	if _prepared_board == null:
		_prepared_board = _board_scenes[GlobalState.selected_board].instantiate()
		_prepared_board.modulate = Color(1, 1, 1, 0)
		# No input or processing until a game starts on it.
		_prepared_board.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_prepared_board)
		_prepared_board.prepare(GlobalState.board_cols, GlobalState.board_rows, GlobalState.board_wrap)
		_prepared_key = key
	if not _prepared_board.is_built():
		_prepared_board.build_step(PREPARE_BUDGET_USEC)


## Frees the background board, returning its cells to the pool.
func _discard_prepared_board() -> void:
	if _prepared_board:
		_prepared_board.clear()
		_prepared_board.free()
		_prepared_board = null
	_prepared_key = []


## Returns the background board if it was built for the current settings
## (finishing it if needed happens in start_game), or a new board.
func _take_board() -> BaseBoard:
	if _prepared_board and _prepared_key == _get_prepare_key():
		var board: BaseBoard = _prepared_board
		_prepared_board = null
		_prepared_key = []
		board.modulate = Color.WHITE
		board.process_mode = Node.PROCESS_MODE_INHERIT
		return board
	_discard_prepared_board()
	var new_board: BaseBoard = _board_scenes[GlobalState.selected_board].instantiate()
	add_child(new_board)
	return new_board


func _game_finished(is_win: bool, _time: float) -> void:
	_final_title.text = "Good job!" if is_win else "Oh no!"
	_board_gui.visible = false
	_final_screen.visible = true


func _toggle_defuse(is_active: bool) -> void:
	GlobalState.is_defusing = is_active


## Instantiates the selected board, starts a new game, and switches to gameplay view.
func _load_game() -> void:
	_board = _take_board()
	var mine_count: int = GlobalState.get_mine_count()

	# Games start in defuse mode. The first tap always opens a cell (see
	# BaseBoard._on_cell_pressed), so the game can start even though the HUD
	# with the defuse button stays hidden until then.
	GlobalState.is_defusing = true
	_defuse_button.button_pressed = true
	# Connect before start_game: a seeded game auto-starts (opens the
	# center cell) from inside it, and on_game_started must not be missed.
	_board.on_game_started.connect(_game_started)
	_board.on_defuse_changed.connect(_defused_changed)
	_board.on_game_finished.connect(_game_finished)
	_board.start_game(GlobalState.board_cols, GlobalState.board_rows, mine_count, GlobalState.board_wrap)

	_main_menu.visible = false
	# Center camera on the board and configure bounds based on mode.
	if GlobalState.board_wrap:
		_camera.reset_view()  # clears any stale bounds from a previous game
		_camera.offset = _board.get_content_size() / 2.0
	else:
		_camera.set_board_bounds(_board.get_board_position(), _board.get_content_size())


func _defused_changed(defused: int) -> void:
	_board_gui.defused_mines = defused


func _game_started(mine_count: int) -> void:
	_board_gui.visible = true
	_board_gui.total_mines = mine_count


## Returns to the main menu, freeing the current board.
func _reset() -> void:
	if _board:
		# clear() returns the interactive cells to the static pool so the
		# next game reuses them instead of re-instantiating every cell.
		_board.clear()
		_board.free()
		_board = null
	GlobalState.is_defusing = false
	_defuse_button.button_pressed = false
	_board_gui.visible = false
	_final_screen.visible = false
	_camera.reset_view()

	# Return to main menu through ScreenManager so overlays are cleared.
	var sm: ScreenManager = $ScreenManager
	sm.show_main_menu(_main_menu)


## Public wrapper used by PauseOverlay: closes the overlay and un-dims the board.
func resume_game() -> void:
	if _board:
		$ScreenManager.hide_pause(_board)


## Public wrapper used by PauseOverlay.
func return_to_menu() -> void:
	_reset()


## Public wrapper used by PauseOverlay to restart the current game.
func restart_game() -> void:
	_reset()
	_load_game()


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
	var current: Control = sm.get_current_screen()
	if current is SettingsMenu:
		# Back out of Settings to whatever opened it (MainMenu or PauseOverlay).
		sm.pop()
	elif _board:
		# Gameplay is active — toggle pause
		if current is PauseOverlay:
			sm.hide_pause(_board)
		else:
			sm.show_pause(_board)
	# Otherwise (plain main menu) the back button does nothing.


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


func _on_wrap_mode_changed(wrap: bool) -> void:
	GlobalState.board_wrap = wrap
