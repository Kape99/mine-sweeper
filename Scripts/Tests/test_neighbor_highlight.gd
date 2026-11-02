## Verifies that holding a revealed cell with nearby mines highlights its
## unexplored neighbors.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"


func _ready() -> void:
	print("\n=== test_neighbor_highlight ===")
	await run()
	_report()


func _is_highlighted(cell: CellBase) -> bool:
	var color: Color = cell._cell_triangle.modulate
	return color.is_equal_approx(CellBase.NEIGHBOR_HIGHLIGHT_COLOR)


func run() -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(3, 3, 0, true)

	# Make one mine so the center cell has nearby == 1.
	var mine: CellBase = board.board_state[0][0]
	mine.mark_as_mine()
	for n: CellBase in board._get_nearby_cells(mine).keys():
		n.increment_nearby()

	var center: CellBase = board.board_state[1][1]
	center.explore()

	# Simulate a long-press on the center cell.
	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2.ZERO
	press.index = 0
	center._on_area_2d_input_event(null, press, 0)

	await wait_wall_ms(CellBase.LONG_PRESS_THRESHOLD_MS + 150)

	var highlighted_count: int = 0
	for row: int in board.rows:
		for col: int in board.cols:
			var cell: CellBase = board.board_state[row][col]
			if cell.is_explored():
				continue
			if _is_highlighted(cell):
				highlighted_count += 1

	assert_true(highlighted_count > 0, "At least one neighbor is highlighted")
	assert_eq(highlighted_count, 8, "All 8 neighbors of center are highlighted")

	# Release and verify highlight clears.
	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2.ZERO
	release.index = 0
	center._on_area_2d_input_event(null, release, 0)

	# Give the board one process frame to run _clear_neighbor_highlight.
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

	var still_highlighted: int = 0
	for row: int in board.rows:
		for col: int in board.cols:
			var cell: CellBase = board.board_state[row][col]
			if cell.is_explored():
				continue
			if _is_highlighted(cell):
				still_highlighted += 1
			assert_eq(cell._cell_state, CellBase.CellState.UNKNOWN, "Unknown cell state unchanged after release")
	assert_eq(still_highlighted, 0, "Highlight clears after release")

	board.free()
	BaseBoard.clear_pools()
