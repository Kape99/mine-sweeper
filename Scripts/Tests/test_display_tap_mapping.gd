## Verifies BaseBoard._find_display_logical_cell(): a tap on a wrap-mode
## copy resolves to the cell drawn under it, for every board shape. Taps
## land on each cell's visible shape (its centroid and points near its
## edges), which for hex and triangle cells is offset from the layout rect.
extends TestCase

const BOARD_SCENES: PackedStringArray = [
	"res://Scenes/Board/square_board.tscn",
	"res://Scenes/Board/hexagon_board.tscn",
	"res://Scenes/Board/triangle_board.tscn",
]

## How far from the centroid toward each vertex a probe tap lands (0..1).
const EDGE_PROBE: float = 0.8


func run() -> void:
	for path: String in BOARD_SCENES:
		_test_board(path)
	# Pooled cells are off-tree and would leak CanvasItem RIDs at exit.
	BaseBoard.clear_pools()


func _test_board(path: String) -> void:
	var name: String = path.get_file().get_basename()
	var board: BaseBoard = load(path).instantiate()
	add_child(board)
	board.start_game(10, 10, 10, true)

	var offsets: Array[Vector2] = board._copy_renderer.get_offsets()
	var copy_offset: Vector2 = offsets[0]
	var to_screen: Transform2D = board.get_viewport().canvas_transform
	var board_origin: Vector2 = board._board_node.global_position

	var copy_misses: int = 0
	var center_hits: int = 0
	for row: Array in board.board_state:
		for cell: CellBase in row:
			for probe: Vector2 in _probe_points(cell):
				var on_copy: Vector2 = to_screen * (board_origin + copy_offset + cell.position + probe)
				if board._find_display_logical_cell(on_copy) != cell:
					copy_misses += 1
				var on_center: Vector2 = to_screen * (board_origin + cell.position + probe)
				if board._find_display_logical_cell(on_center) != null:
					center_hits += 1
	assert_eq(copy_misses, 0, "%s: taps on a copy resolve to the cell drawn there" % name)
	assert_eq(center_hits, 0, "%s: taps on the center tile are left to the cells' Area2D" % name)
	board.free()


## The visible shape's centroid plus points partway toward each vertex,
## in the cell's own space.
func _probe_points(cell: CellBase) -> Array[Vector2]:
	var polygon: PackedVector2Array = cell.get_render_layout().polygon
	var centroid: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		centroid += point
	centroid /= polygon.size()
	var probes: Array[Vector2] = [centroid]
	for point: Vector2 in polygon:
		probes.append(centroid.lerp(point, EDGE_PROBE))
	return probes
