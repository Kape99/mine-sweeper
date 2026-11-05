## Verifies mine placement: the safe zone around the first tap, that the
## mine count / win target match what was actually placed on boards too
## small for the full safe zone, and that reveal waves don't cancel each other.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"


func run() -> void:
	_test_full_safe_zone()
	_test_small_board_places_all_mines()
	_test_reveal_waves_overlap()
	BaseBoard.clear_pools()


func _test_full_safe_zone() -> void:
	var board: BaseBoard = _load_board(18, 18, 49)
	var first: CellBase = board.board_state[9][9]
	board._first_move(first)
	var mines_in_zone: int = 0
	for cell: CellBase in board._get_nearby_cells(first, BaseBoard.SAFE_ZONE_DISTANCE).keys():
		if cell.is_mine():
			mines_in_zone += 1
	assert_false(first.is_mine(), "18x18: first tapped cell is not a mine")
	assert_eq(mines_in_zone, 0, "18x18: no mines within the 3x3 zone of the first tap")
	assert_eq(_count_mines(board), 49, "18x18: all 49 requested mines placed")
	board.free()


func _test_small_board_places_all_mines() -> void:
	# 5x5 with 16 mines is the menu's maximum; the 3x3 safe zone covers 9
	# cells, leaving exactly 16 candidates — it just barely doesn't shrink.
	var board: BaseBoard = _load_board(5, 5, 16)
	var first: CellBase = board.board_state[2][2]
	var started_with: Array[int] = []
	board.on_game_started.connect(func(count: int) -> void: started_with.append(count))
	board._first_move(first)
	assert_false(first.is_mine(), "5x5: first tapped cell is not a mine")
	assert_eq(_count_mines(board), 16, "5x5: all 16 requested mines placed")
	assert_eq(board.mines, 16, "5x5: board.mines matches placed mines")
	assert_eq(board._to_be_explored, 9, "5x5: win target is 25 - 16 = 9 safe cells")
	assert_eq(started_with, [16] as Array[int], "5x5: HUD is told the real mine count")
	board.free()


func _test_reveal_waves_overlap() -> void:
	var board: BaseBoard = _load_board(5, 5, 0)
	var first: Tween = board._create_reveal_tween()
	first.tween_interval(1.0)
	var second: Tween = board._create_reveal_tween()
	second.tween_interval(1.0)
	assert_true(first.is_valid(), "Starting a second reveal wave keeps the first one running")
	board.clear()
	assert_false(first.is_valid() or second.is_valid(), "clear() stops all reveal waves")
	board.free()


func _count_mines(board: BaseBoard) -> int:
	var count: int = 0
	for row: int in board.rows:
		for col: int in board.cols:
			if board.board_state[row][col].is_mine():
				count += 1
	return count


func _load_board(cols: int, rows: int, mines: int) -> BaseBoard:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(cols, rows, mines, false)
	return board
