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
	_assert_copy_coverage(wrap, "Square")
	var corner: CellBase = wrap.board_state[0][0]
	assert_eq(wrap._get_nearby_cells(corner, 1).size(), 8,
		"Square wrap: corner (0,0) has 8 wrapped neighbors")
	wrap.free()

	var classic: BaseBoard = _load_board(SQUARE_SCENE, 9, 12, 15, false)
	assert_eq(_copy_count(classic), 0, "Square classic: no copies")
	var classic_corner: CellBase = classic.board_state[0][0]
	assert_eq(classic._get_nearby_cells(classic_corner, 1).size(), 3,
		"Square classic: corner (0,0) has 3 in-bounds neighbors")
	classic.free()


func _test_hexagon() -> void:
	var wrap: BaseBoard = _load_board(HEX_SCENE, 9, 13, 15, true)
	_assert_copy_coverage(wrap, "Hex")
	assert_eq(wrap.board_state.size(), 14, "Hex wrap: odd row count (13) is rounded up to 14")
	assert_eq(_count_asymmetric_pairs(wrap), 0, "Hex wrap: neighbor relation is symmetric across the seam")
	wrap.free()

	var classic: BaseBoard = _load_board(HEX_SCENE, 9, 13, 15, false)
	assert_eq(_copy_count(classic), 0, "Hex classic: no copies")

	# A hex corner cell should have fewer valid neighbors in classic mode
	# than wrap mode, since some neighbors fall outside the board.
	var corner: CellBase = classic.board_state[0][0]
	var classic_neighbors: int = classic._get_nearby_cells(corner, 1).size()
	assert_true(classic_neighbors < 6, "Hex classic: corner has fewer than 6 neighbors (edge-clipped)")
	classic.free()


func _test_triangle() -> void:
	var wrap: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 13, 15, true)
	_assert_copy_coverage(wrap, "Triangle")
	assert_eq(Vector2i(wrap.cols, wrap.rows), Vector2i(12, 14), "Triangle wrap: odd 11x13 is rounded up to 12x14")
	assert_eq(_count_asymmetric_pairs(wrap), 0, "Triangle wrap: neighbor relation is symmetric across the seam")
	wrap.free()

	var classic: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 12, 15, false)
	assert_eq(_copy_count(classic), 0, "Triangle classic: no copies")

	var corner: CellBase = classic.board_state[0][0]
	var classic_neighbors: int = classic._get_nearby_cells(corner, 1).size()
	var wrap_reload: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 12, 15, true)
	var wrap_corner: CellBase = wrap_reload.board_state[0][0]
	var wrap_neighbors: int = wrap_reload._get_nearby_cells(wrap_corner, 1).size()
	assert_true(classic_neighbors < wrap_neighbors,
		"Triangle classic: corner has fewer neighbors than wrap (%d < %d)" % [classic_neighbors, wrap_neighbors])
	classic.free()
	wrap_reload.free()


## Number of copies drawn around the logical tile (0 in classic mode).
func _copy_count(board: BaseBoard) -> int:
	return board._copy_renderer.get_offsets().size() if board._copy_renderer else 0


## The copy grid is computed from the viewport size and the camera's
## minimum zoom: per axis, n × board ≥ view + board (block covers the
## zoomed-out viewport plus the half-board recenter drift), n odd and at
## least MIN_TILE_GRID_SIZE, and n the smallest such odd size.
func _assert_copy_coverage(board: BaseBoard, shape: String) -> void:
	var counts: Vector2i = board._tile_grid_counts
	assert_eq(_copy_count(board), counts.x * counts.y - 1,
		"%s wrap: every tile of the %dx%d block but the center is a copy" % [shape, counts.x, counts.y])
	assert_true(counts.x % 2 == 1 and counts.y % 2 == 1,
		"%s wrap: copy grid is odd (centered on the logical tile)" % shape)
	assert_true(counts.x >= BaseBoard.MIN_TILE_GRID_SIZE and counts.y >= BaseBoard.MIN_TILE_GRID_SIZE,
		"%s wrap: at least one ring of copies" % shape)
	var view: Vector2 = board.get_viewport().get_visible_rect().size / CameraController.MIN_ZOOM
	var board_size: Vector2 = board.get_board_size()
	assert_true(counts.x * board_size.x >= view.x + board_size.x and
		counts.y * board_size.y >= view.y + board_size.y,
		"%s wrap: block covers the min-zoom viewport plus recenter drift" % shape)
	assert_true((counts.x - 2) * board_size.x < view.x + board_size.x and
		(counts.y - 2) * board_size.y < view.y + board_size.y,
		"%s wrap: grid is the smallest odd size covering the viewport" % shape)


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
