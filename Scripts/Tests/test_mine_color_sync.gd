## Verifies that a mine explosion shows Color.RED + white icon on both the
## logical cell and its wrap-mode display copies.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"


func _ready() -> void:
	print("\n=== test_mine_color_sync ===")
	await run()
	_report()


func run() -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.start_game(3, 3, 1, true)

	var mine: CellBase = board.board_state[1][1]
	mine.mark_as_mine()
	# Trigger the explosion reveal path, which syncs display copies.
	mine.explore()

	# Logical cell should be red with white mine icon.
	assert_eq(mine._cell_triangle.modulate, Color.RED, "Logical mine polygon is red")
	assert_eq(mine._cell_icon.modulate, Color.WHITE, "Logical mine icon is white")

	# Find a display copy in a non-center tile.
	var display_copy: Control = null
	for tile_idx: int in board._tiles.size():
		if tile_idx == board.CENTER_TILE_INDEX:
			continue
		var tile: GridContainer = board._tiles[tile_idx]
		var idx: int = mine.coord.y * board.cols + mine.coord.x
		if idx >= 0 and idx < tile.get_child_count():
			display_copy = tile.get_child(idx)
			break
	assert_true(display_copy != null, "Found a display copy of the mine cell")

	var poly: Polygon2D = display_copy.get_child(0)
	var icon: TextureRect = display_copy.get_child(2)
	assert_eq(poly.modulate, Color.RED, "Display copy polygon is red")
	assert_eq(icon.modulate, Color.WHITE, "Display copy icon is white")

	board.free()
	BaseBoard.clear_pools()
