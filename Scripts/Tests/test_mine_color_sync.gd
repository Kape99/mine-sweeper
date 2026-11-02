## Verifies that a mine explosion shows Color.RED + white icon on both the
## logical cell and its wrap-mode copies, and that the copies are redrawn.
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
	# Let the initial draw of the copies happen.
	await get_tree().process_frame
	var renderer: BoardCopyRenderer = board._copy_renderer
	var mine: CellBase = board.board_state[1][1]
	assert_false(renderer.is_redraw_pending(mine.coord), "Copies are drawn after the first frame")

	mine.mark_as_mine()
	# Trigger the explosion reveal path, which syncs display copies.
	mine.explore()

	# Logical cell should be red with white mine icon.
	assert_eq(mine._cell_triangle.modulate, Color.RED, "Logical mine polygon is red")
	assert_eq(mine._cell_icon.modulate, Color.WHITE, "Logical mine icon is white")

	# The copies draw exactly what get_cell_visual() returns.
	var visual: Dictionary = renderer.get_cell_visual(mine)
	assert_eq(visual.fill, Color.RED, "Copy of the mine is drawn red")
	assert_eq(visual.icon_modulate, Color.WHITE, "Copy of the mine icon is drawn white")
	assert_eq(visual.icon, CellBase.MINE_ICON, "Copy of the mine shows the mine icon")
	assert_true(renderer.is_redraw_pending(mine.coord), "Explosion schedules a redraw of the copies")
	await get_tree().process_frame
	assert_false(renderer.is_redraw_pending(mine.coord), "Copies are redrawn on the next frame")

	board.free()
	BaseBoard.clear_pools()
