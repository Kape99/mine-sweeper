## Verifies that a mine explosion shows the scheme's danger color + white
## icon on both the logical cell and its wrap-mode copies, that the copies
## are redrawn, and that revealed numbers get the scheme's light-to-dark
## color and a size that grows with the count, on copies too.
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
	assert_eq(mine._cell_triangle.modulate, GlobalState.scheme.danger, "Logical mine polygon uses the danger color")
	assert_eq(mine._cell_icon.modulate, Color.WHITE, "Logical mine icon is white")

	# The copies draw exactly what get_cell_visual() returns.
	var visual: Dictionary = renderer.get_cell_visual(mine)
	assert_eq(visual.fill, GlobalState.scheme.danger, "Copy of the mine is drawn in the danger color")
	assert_eq(visual.icon_modulate, Color.WHITE, "Copy of the mine icon is drawn white")
	assert_eq(visual.icon, CellBase.MINE_ICON, "Copy of the mine shows the mine icon")
	assert_true(renderer.is_redraw_pending(mine.coord), "Explosion schedules a redraw of the copies")
	await get_tree().process_frame
	assert_false(renderer.is_redraw_pending(mine.coord), "Copies are redrawn on the next frame")


	# A revealed neighbor shows its count in that count's color, and its
	# copies draw the same color.
	var numbered: CellBase = board.board_state[0][0]
	numbered.increment_nearby()
	numbered.explore()
	var number_color: Color = GlobalState.scheme.get_number_color(1)
	assert_eq(numbered._cell_text.modulate, number_color, "A '1' uses the scheme's color for 1")
	assert_eq(renderer.get_cell_visual(numbered).text_modulate, number_color,
		"Copy of the '1' is drawn in the same color")
	assert_eq(numbered._cell_text.get_theme_color("font_color"), Color.WHITE,
		"Cell label base color is white, so the number color is not darkened by the UI theme")
	assert_eq(numbered.get_text_font_size(), CellBase.NUMBER_FONT_SIZE_MIN, "A '1' uses the smallest number size")
	assert_eq(renderer.get_cell_visual(numbered).font_size, CellBase.NUMBER_FONT_SIZE_MIN,
		"Copy of the '1' is drawn at the same size")

	# The scale runs from 1 (light, small) to 12 (dark, large), steadily.
	var scheme: ColorScheme = GlobalState.scheme
	assert_eq(scheme.get_number_color(1), scheme.number_light, "1 uses the light number color")
	assert_true(scheme.get_number_color(ColorScheme.MAX_COUNT).is_equal_approx(scheme.number_dark),
		"12 uses the dark number color")
	assert_eq(CellBase.number_font_size(ColorScheme.MAX_COUNT), CellBase.NUMBER_FONT_SIZE_MAX, "12 uses the largest number size")
	var darkening: bool = true
	var growing: bool = true
	for count: int in range(2, ColorScheme.MAX_COUNT + 1):
		if scheme.get_number_color(count).get_luminance() >= scheme.get_number_color(count - 1).get_luminance():
			darkening = false
		if CellBase.number_font_size(count) < CellBase.number_font_size(count - 1):
			growing = false
	assert_true(darkening, "Each higher count is darker than the one before")
	assert_true(growing, "Number size never shrinks as the count rises")

	# A pooled cell reused for a new game drops the number size.
	numbered.reset_state()
	assert_false(numbered._cell_text.has_theme_font_size_override("font_size"),
		"Resetting a cell clears its number size")

	board.free()
	BaseBoard.clear_pools()
