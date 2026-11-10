## Regression: in defuse mode a tap must toggle defuse exactly once.
## If cell.defuse() were invoked twice per tap (once in cell.gd and once in
## BaseBoard._on_cell_pressed, or once per emulated touch+mouse event), the
## cell would end un-flagged. Also covers the tap model: single tap runs
## the mode action (open in normal mode, flag in defuse mode), double tap
## always opens, and the first tap of a game always opens.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"

var _press: InputEventScreenTouch
var _release: InputEventScreenTouch
var _mouse_press: InputEventMouseButton
var _mouse_release: InputEventMouseButton


func _ready() -> void:
	print("\n=== test_defuse_mode_toggle ===")
	await run()
	_report()


func run() -> void:
	_build_events()

	_test_first_tap(false, "single tap")
	_test_first_tap(true, "double tap")

	var board: BaseBoard = _started_board()

	# --- Every defuse-mode tap toggles exactly once ---
	board.set_defusing(true)
	var cell: CellBase = board.board_state[1][1]
	# Wait out the double-tap window between taps so each counts as a
	# single (a second tap inside the window is a double tap, which opens).
	_tap(cell)
	assert_true(cell.is_defused(), "Defuse mode tap defuses exactly once (cell flagged)")
	await wait_wall_ms(Settings.double_tap_window_ms + 50)
	_tap(cell)
	assert_false(cell.is_defused(), "Second defuse mode tap toggles back (defuse called once)")

	# Real input: with input pointing emulation, one physical tap reaches the
	# cell as BOTH a touch event and a mouse-button event.
	await wait_wall_ms(Settings.double_tap_window_ms + 50)
	_emulated_tap(cell)
	assert_true(cell.is_defused(), "Emulated touch+mouse tap defuses exactly once")
	cell.defuse()  # back to unknown

	# Normal mode: single tap opens, even when duplicated by emulation.
	board.set_defusing(false)
	var a: CellBase = board.board_state[0][0]
	var open_count: Array[int] = [0]
	a.cell_open_requested.connect(func(_c: CellBase) -> void: open_count[0] += 1)
	_emulated_tap(a)
	assert_eq(open_count[0], 0, "Emulated touch+mouse single tap is not a double tap")
	assert_true(a.is_explored(), "Normal mode: single tap opens")

	# Normal mode: double tap also opens (already open here: it re-requests).
	_emulated_tap(a)
	assert_eq(open_count[0], 1, "Double tap requests open once")

	# Defuse mode: single tap still flags immediately.
	board.set_defusing(true)
	var b: CellBase = board.board_state[0][1]
	_tap(b)
	assert_true(b.is_defused(), "Defuse mode single tap flags immediately with double tap on")

	# Defuse mode: double tap opens (removes the flag the first tap placed).
	_tap(b)
	assert_true(b.is_explored(), "Double tap opens in defuse mode")
	assert_false(b.is_defused(), "Opened cell is no longer flagged")

	# Defuse mode: double tap on an already-flagged cell still opens it.
	var c: CellBase = board.board_state[0][2]
	c.defuse()
	_tap(c)
	assert_false(c.is_defused(), "First tap unflags")
	_tap(c)
	assert_true(c.is_explored(), "Double tap opens a previously flagged cell")

	board.set_defusing(false)

	board.free()
	BaseBoard.clear_pools()


## The first tap of a game opens the cell and starts the game, even in
## defuse mode, whether it's a single tap or a double tap.
func _test_first_tap(tap_twice: bool, label: String) -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(3, 3, 0, true, "")
	var cell: CellBase = board.board_state[1][1]
	_emulated_tap(cell)
	if tap_twice:
		_emulated_tap(cell)
	assert_true(board._is_game_started and cell.is_explored(), "First %s opens and starts the game in defuse mode" % label)
	assert_false(cell.is_defused(), "First %s does not flag" % label)
	board.free()
	BaseBoard.clear_pools()


## A 3x3 wrapping board with the game already started and one mine at (2,2).
## On a 3x3 torus every cell neighbors every other, so each non-mine cell
## shows 1 and opening one doesn't cascade.
func _started_board() -> BaseBoard:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(3, 3, 0, true)
	var mine: CellBase = board.board_state[2][2]
	mine.mark_as_mine()
	for n: CellBase in board._get_nearby_cells(mine).keys():
		n.increment_nearby()
	board._is_game_started = true
	return board


func _build_events() -> void:
	_press = InputEventScreenTouch.new()
	_press.pressed = true
	_press.position = Vector2.ZERO
	_release = InputEventScreenTouch.new()
	_release.pressed = false
	_release.position = Vector2.ZERO
	_mouse_press = InputEventMouseButton.new()
	_mouse_press.button_index = MOUSE_BUTTON_LEFT
	_mouse_press.pressed = true
	_mouse_press.position = Vector2.ZERO
	_mouse_release = InputEventMouseButton.new()
	_mouse_release.button_index = MOUSE_BUTTON_LEFT
	_mouse_release.pressed = false
	_mouse_release.position = Vector2.ZERO


func _tap(cell: CellBase) -> void:
	cell._on_area_2d_input_event(null, _press, 0)
	cell._on_area_2d_input_event(null, _release, 0)


## One physical tap as the engine delivers it with pointing emulation on.
func _emulated_tap(cell: CellBase) -> void:
	cell._on_area_2d_input_event(null, _mouse_press, 0)
	cell._on_area_2d_input_event(null, _press, 0)
	cell._on_area_2d_input_event(null, _mouse_release, 0)
	cell._on_area_2d_input_event(null, _release, 0)
