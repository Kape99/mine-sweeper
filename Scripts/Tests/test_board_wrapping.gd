## Verifies BaseBoard's wrap vs. classic mode: tile count, and neighbor
## detection at a corner cell (where the difference is observable) for
## all three board shapes.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"
const HEX_SCENE: String = "res://Scenes/Board/hexagon_board.tscn"
const TRIANGLE_SCENE: String = "res://Scenes/Board/triangle_board.tscn"


func run() -> void:
	_test_square()
	_test_hexagon()
	_test_triangle()
	# Pooled cells are off-tree and would leak CanvasItem RIDs at exit.
	BaseBoard.clear_pools()


func _test_square() -> void:
	var wrap: BaseBoard = _load_board(SQUARE_SCENE, 9, 12, 15, true)
	assert_eq(wrap._tiles.size(), 9, "Square wrap: builds 9 tiles")
	var corner: CellBase = wrap.board_state[0][0]
	assert_eq(wrap._get_nearby_cells(corner, 1).size(), 8,
		"Square wrap: corner (0,0) has 8 wrapped neighbors")
	wrap.free()

	var classic: BaseBoard = _load_board(SQUARE_SCENE, 9, 12, 15, false)
	assert_eq(classic._tiles.size(), 1, "Square classic: builds 1 tile")
	var classic_corner: CellBase = classic.board_state[0][0]
	assert_eq(classic._get_nearby_cells(classic_corner, 1).size(), 3,
		"Square classic: corner (0,0) has 3 in-bounds neighbors")
	classic.free()


func _test_hexagon() -> void:
	var wrap: BaseBoard = _load_board(HEX_SCENE, 9, 13, 15, true)
	assert_eq(wrap._tiles.size(), 9, "Hex wrap: builds 9 tiles")
	assert_eq(wrap.board_state.size(), 14, "Hex wrap: odd row count (13) is rounded up to 14")
	assert_eq(_count_asymmetric_pairs(wrap), 0, "Hex wrap: neighbor relation is symmetric across the seam")
	wrap.free()

	var classic: BaseBoard = _load_board(HEX_SCENE, 9, 13, 15, false)
	assert_eq(classic._tiles.size(), 1, "Hex classic: builds 1 tile (no copies)")

	# A hex corner cell should have fewer valid neighbors in classic mode
	# than wrap mode, since some neighbors fall outside the board.
	var corner: CellBase = classic.board_state[0][0]
	var classic_neighbors: int = classic._get_nearby_cells(corner, 1).size()
	assert_true(classic_neighbors < 6, "Hex classic: corner has fewer than 6 neighbors (edge-clipped)")
	classic.free()


func _test_triangle() -> void:
	var wrap: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 13, 15, true)
	assert_eq(wrap._tiles.size(), 9, "Triangle wrap: builds 9 tiles")
	assert_eq(Vector2i(wrap.cols, wrap.rows), Vector2i(12, 14), "Triangle wrap: odd 11x13 is rounded up to 12x14")
	assert_eq(_count_asymmetric_pairs(wrap), 0, "Triangle wrap: neighbor relation is symmetric across the seam")
	wrap.free()

	var classic: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 12, 15, false)
	assert_eq(classic._tiles.size(), 1, "Triangle classic: builds 1 tile (no copies)")

	var corner: CellBase = classic.board_state[0][0]
	var classic_neighbors: int = classic._get_nearby_cells(corner, 1).size()
	var wrap_reload: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 12, 15, true)
	var wrap_corner: CellBase = wrap_reload.board_state[0][0]
	var wrap_neighbors: int = wrap_reload._get_nearby_cells(wrap_corner, 1).size()
	assert_true(classic_neighbors < wrap_neighbors,
		"Triangle classic: corner has fewer neighbors than wrap (%d < %d)" % [classic_neighbors, wrap_neighbors])
	classic.free()
	wrap_reload.free()


## Number of (a, b) pairs where b is a neighbor of a but a is not a
## neighbor of b. Must be 0, or mine counts disagree with flood fill/chord.
func _count_asymmetric_pairs(board: BaseBoard) -> int:
	var count: int = 0
	for row: int in board.rows:
		for col: int in board.cols:
			var a: CellBase = board.board_state[row][col]
			for b: CellBase in board._get_nearby_cells(a).keys():
				if not board._get_nearby_cells(b).has(a):
					count += 1
	return count


func _load_board(scene_path: String, cols: int, rows: int, mines: int, wrap: bool) -> BaseBoard:
	var board: BaseBoard = load(scene_path).instantiate()
	add_child(board)
	board.start_game(cols, rows, mines, wrap)
	return board
