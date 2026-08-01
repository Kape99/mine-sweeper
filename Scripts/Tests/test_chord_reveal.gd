## Verifies chord reveal: when defused neighbors match the cell's number,
## all remaining hidden neighbors are revealed in one wave.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"


func _ready() -> void:
	print("\n=== test_chord_reveal ===")
	await run()
	_report()


func run() -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(3, 3, 0, true)

	# Manually create two mines in opposite corners.
	var mine_a: CellBase = board.board_state[0][0]
	var mine_b: CellBase = board.board_state[2][2]
	mine_a.mark_as_mine()
	mine_b.mark_as_mine()
	for n: CellBase in board._get_nearby_cells(mine_a).keys():
		n.increment_nearby()
	for n: CellBase in board._get_nearby_cells(mine_b).keys():
		n.increment_nearby()

	var center: CellBase = board.board_state[1][1]
	center.explore()

	# Flag the two mines correctly.
	mine_a.defuse()
	mine_b.defuse()

	# Trigger chord reveal on the center cell (nearby == 2, two flags).
	board._chord_reveal(center)

	# Wait for the reveal tween to finish.
	await get_tree().create_timer(0.5).timeout

	# All non-mine neighbors of center should now be explored.
	var expected_explored: Array[CellBase] = [
		board.board_state[0][1],
		board.board_state[0][2],
		board.board_state[1][0],
		board.board_state[1][2],
		board.board_state[2][0],
		board.board_state[2][1],
	]
	for cell: CellBase in expected_explored:
		assert_true(cell.is_explored(), "Neighbor (%d,%d) revealed by chord" % [cell.coord.x, cell.coord.y])

	assert_true(mine_a.is_defused(), "Mine A stays flagged")
	assert_true(mine_b.is_defused(), "Mine B stays flagged")
	assert_false(center.is_defused(), "Center remains explored")

	board.free()
	BaseBoard.clear_pools()
