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

## Arguments of the running game's [method _load_game] call, for restarts.
var _game_args: Array = []

## Whether the running game is the daily challenge (the only mode with a
## leaderboard).
var _is_daily: bool = false

## When [member _carry_timer] is set, the next game's timer counts from
## [member _carry_timer_start] ([method Time.get_ticks_msec] time) instead
## of from zero. Set by a daily restart, so retrying keeps the clock running.
var _carry_timer: bool = false
var _carry_timer_start: int = 0


func _ready() -> void:
	_board_scenes = {
		0: _triangle_board_scene,
		1: _square_board_scene,
		2: _hexagon_board_scene,
	}
	# Clean up static cell pools on exit so off-tree pooled nodes don't leak RIDs.
	if not get_tree().root.tree_exiting.is_connected(BaseBoard.clear_pools):
		get_tree().root.tree_exiting.connect(BaseBoard.clear_pools)
	_camera.reset_view()

	_board_gui.pause_requested.connect(_on_pause_requested)
	_defuse_button.modulate = GlobalState.scheme.accent
	_defuse_button.toggled.connect(_toggle_defuse)

	# Connect to the fresh MainMenu's intent signals.
	_main_menu.start_requested.connect(_load_game)
	_main_menu.settings_requested.connect(_on_settings_pressed)
	_main_menu.account_requested.connect(_on_account_pressed)
	_main_menu.new_game_requested.connect(_on_new_game_pressed)

	# Hidden until a game ends. The main menu covers it, but overlays that
	# hide the menu in place (Settings, New game, Account) would show it.
	_final_screen.visible = false
	_final_screen.reset.connect(_reset)
	_final_screen.continue_requested.connect(restart_game)
	_final_screen.login_requested.connect(_on_account_pressed)

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


## Everything a freshly built board depends on, for the menu's current
## settings. Cell colors are set when cells are created, so the color
## scheme is part of it.
func _get_prepare_key() -> Array:
	return _make_prepare_key(GlobalState.selected_board, GlobalState.board_cols, GlobalState.board_rows, GlobalState.board_wrap)


## Same as [method _get_prepare_key], for explicit board settings (e.g. a
## daily challenge, whose settings don't come from the menu).
func _make_prepare_key(board: int, cols: int, rows: int, board_wrap: bool) -> Array:
	return [board, cols, rows, board_wrap, GlobalState.selected_scheme]


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


## Returns the background board if it was built for exactly these settings
## (finishing it if needed happens in start_game), or a new board. The
## settings are the game's, not the menu's: a daily challenge picks its own.
func _take_board(board_idx: int, cols: int, rows: int, board_wrap: bool) -> BaseBoard:
	if _prepared_board and _prepared_key == _make_prepare_key(board_idx, cols, rows, board_wrap):
		var board: BaseBoard = _prepared_board
		_prepared_board = null
		_prepared_key = []
		board.modulate = Color.WHITE
		board.process_mode = Node.PROCESS_MODE_INHERIT
		return board
	_discard_prepared_board()
	var new_board: BaseBoard = _board_scenes[board_idx].instantiate()
	add_child(new_board)
	return new_board


func _game_finished(is_win: bool, _time: float) -> void:
	_board_gui.stop_timer()
	_final_screen.game_finished(is_win, _board_gui.elapsed_seconds(), _board.mines, _board.count_defused_mines(), _is_daily)
	_board_gui.visible = false
	_final_screen.visible = true


func _toggle_defuse(is_active: bool) -> void:
	GlobalState.is_defusing = is_active
	if _board:
		_board.set_defusing(is_active)

## Instantiates the selected board, starts a new game, and switches to gameplay view.
func _load_game(board: int, cols: int, rows: int, mine_perc: float, board_wrap: bool, board_seed: String = "", is_daily: bool = false) -> void:
	# Remembered so a restart replays this exact game, not the menu's settings.
	_game_args = [board, cols, rows, mine_perc, board_wrap, board_seed, is_daily]
	_is_daily = is_daily
	_board = _take_board(board, cols, rows, board_wrap)
	var mine_count: int =  maxi(1, roundi(rows * cols * mine_perc))

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
	_board.start_game(cols, rows, mine_count, board_wrap, board_seed)

	_main_menu.visible = false
	_final_screen.visible = false
	# Center camera on the board and configure bounds based on mode.
	if board_wrap:
		_camera.reset_view()  # clears any stale bounds from a previous game
		_camera.offset = _board.get_content_size() / 2.0
	else:
		_camera.set_board_bounds(_board.get_board_position(), _board.get_content_size())


func _defused_changed(defused: int) -> void:
	_board_gui.defused_mines = defused


func _game_started(mine_count: int) -> void:
	_board_gui.visible = true
	if _carry_timer:
		_board_gui.resume_timer(_carry_timer_start)
	else:
		_board_gui.start_timer()
	_carry_timer = false
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


## Public wrapper used by PauseOverlay to restart the current game with the
## same settings it was started with (a daily restarts the same daily).
##
## A daily (restarted from the pause menu, or continued after a defeat)
## keeps its timer running: retries until the win all count toward the
## time submitted to the leaderboard. A daily always starts itself (it
## opens its seeded center cell), so the carried start is used right away.
func restart_game() -> void:
	var args: Array = _game_args
	if _is_daily:
		_carry_timer = true
		_carry_timer_start = _board_gui.timer_start_msec()
	_reset()
	if args.is_empty():
		return
	_load_game.callv(args)


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
	if current is SettingsMenu or current is AccountMenu or current is NewGameMenu:
		# Back out of Settings/Account/New game to whatever opened it
		# (MainMenu, PauseOverlay or the end screen).
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


## Opens the Account screen over the main menu or the end screen (which
## sits under the screens container, so it stays visible behind it).
func _on_account_pressed() -> void:
	var sm: ScreenManager = $ScreenManager
	sm.push(
		load("res://Scenes/Menu/AccountMenu.tscn").instantiate(),
		true,
		false  # dismiss_current=false — keep the screen below alive
	)


## Opens the New game sheet over the main menu. Its PLAY closes the sheet
## and starts a game with the settings it saved.
func _on_new_game_pressed() -> void:
	var sm: ScreenManager = $ScreenManager
	var sheet: NewGameMenu = load("res://Scenes/Menu/NewGameMenu.tscn").instantiate()
	sheet.play_requested.connect(func() -> void:
		sm.pop()
		_main_menu._on_start())
	sm.push(sheet, true, false)  # dismiss_current=false — keep MainMenu alive
