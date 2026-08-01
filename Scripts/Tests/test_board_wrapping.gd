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
	assert_eq(wrap.board_state.size(), 13, "Hex wrap: board_state has 13 rows")
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
	var wrap: BaseBoard = _load_board(TRIANGLE_SCENE, 11, 12, 15, true)
	assert_eq(wrap._tiles.size(), 9, "Triangle wrap: builds 9 tiles")
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


func _load_board(scene_path: String, cols: int, rows: int, mines: int, wrap: bool) -> BaseBoard:
	var board: BaseBoard = load(scene_path).instantiate()
	add_child(board)
	board.start_game(cols, rows, mines, wrap)
	return board
