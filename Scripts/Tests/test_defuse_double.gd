## Regression: in defuse mode a tap must toggle defuse exactly once.
## If cell.defuse() were invoked twice per tap (once in cell.gd and once in
## BaseBoard._on_cell_pressed), the cell would end un-flagged.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"


func _ready() -> void:
	print("\n=== test_defuse_mode_toggle ===")
	await run()
	_report()


func run() -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(3, 3, 0, true)

	GlobalState.is_defusing = true

	var cell: CellBase = board.board_state[1][1]
	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2.ZERO
	press.index = 0
	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2.ZERO
	release.index = 0

	# First tap: defuse once.
	cell._on_area_2d_input_event(null, press, 0)
	cell._on_area_2d_input_event(null, release, 0)
	assert_true(cell.is_defused(), "Defuse mode tap defuses exactly once (cell flagged)")

	# Second tap: defuse once more (toggle back).
	cell._on_area_2d_input_event(null, press, 0)
	cell._on_area_2d_input_event(null, release, 0)
	assert_false(cell.is_defused(), "Second defuse mode tap toggles back (defuse called once)")

	GlobalState.is_defusing = false

	board.free()
	BaseBoard.clear_pools()
