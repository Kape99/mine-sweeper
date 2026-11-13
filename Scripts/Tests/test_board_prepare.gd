## Verifies building the board in the background: BaseBoard's stepped
## build (prepare / build_step / start_game reuse), and base.gd preparing
## the next board while the menu is open and handing it to the game.
extends TestCase

const SQUARE_SCENE: String = "res://Scenes/Board/square_board.tscn"
const BASE_SCENE: String = "res://Scenes/base.tscn"


func _ready() -> void:
	print("\n=== test_board_prepare ===")
	await run()
	_report()


func run() -> void:
	_test_stepped_build()
	_test_unprepared_dimensions_rebuild()
	await _test_menu_prepares_next_board()
	await _test_daily_uses_its_own_settings()
	BaseBoard.clear_pools()


func _test_stepped_build() -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.prepare(20, 20, true)
	assert_false(board.build_step(0), "A zero budget builds only a few cells")
	assert_true(board._build_next > 0 and board._build_next < 400, "Stepped build makes progress without finishing")
	var steps: int = 1
	while not board.build_step(0) and steps < 10000:
		steps += 1
	assert_true(board.is_built(), "Stepped build finishes, copies included")
	assert_eq(board._copy_renderer._hidden_chunks.size(), 0, "Every copy chunk is shown once built")

	var cell: CellBase = board.board_state[19][19]
	var step: Vector2 = board._cell_size + Vector2(BaseBoard.GRID_H_SEPARATION, BaseBoard.GRID_V_SEPARATION)
	assert_eq(cell.position, Vector2(19, 19) * step, "Cells sit on the uniform grid")

	var first: CellBase = board.board_state[0][0]
	assert_true(board.is_prepared_for(20, 20, true), "Board reports it's prepared for its settings")
	board.start_game(20, 20, 40, true)
	assert_eq(board.board_state[0][0], first, "start_game reuses the prepared cells")
	assert_eq(board._to_be_explored, 400 - 40, "start_game sets the win target on a prepared board")
	assert_false(board.is_prepared_for(20, 20, true) and board._is_game_started, "A started game is not reusable")
	board.free()


func _test_unprepared_dimensions_rebuild() -> void:
	var board: BaseBoard = load(SQUARE_SCENE).instantiate()
	add_child(board)
	board.prepare(10, 10, false)
	board.build_step(-1)
	assert_false(board.is_prepared_for(12, 10, false), "Different size is not a match")
	assert_false(board.is_prepared_for(10, 10, true), "Different wrap mode is not a match")
	board.start_game(12, 10, 10, false)
	assert_eq(Vector2i(board.cols, board.rows), Vector2i(12, 10), "start_game rebuilds for new dimensions")
	assert_true(board.is_built(), "Rebuilt board is complete")
	board.free()


func _test_menu_prepares_next_board() -> void:
	GlobalState.selected_board = 1  # Square
	GlobalState.board_cols = 8
	GlobalState.board_rows = 8
	GlobalState.board_wrap = false
	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)

	var prepared: BaseBoard = await _wait_for_prepared(base)
	assert_true(prepared != null and prepared.is_built(), "Menu builds the next board in the background")
	if prepared == null:
		base.free()
		return
	assert_eq(prepared.modulate.a, 0.0, "Background board is invisible")
	# Taps reach a cell only if it can process (physics picking and the
	# board's _unhandled_input both check). Simulated clicks don't reach
	# physics picking in a headless run, so this checks the gate directly.
	var cell: CellBase = prepared.board_state[3][3]
	assert_false(prepared.can_process() or cell.can_process() or cell.get_node("Area2D").can_process(),
		"Background board and its cells take no input")
	prepared._on_cell_pressed(cell, cell.nearby)
	assert_false(prepared._is_game_started or cell.is_explored(), "A tap reaching the background board is ignored")

	# Changing a setting rebuilds it after the settle delay.
	GlobalState.board_rows = 10
	await wait_wall_ms(base.PREPARE_SETTLE_MSEC + 100)
	prepared = await _wait_for_prepared(base)
	assert_true(prepared != null and prepared.rows == 10, "Changing the size rebuilds the background board")

	base._load_game(GlobalState.selected_board, GlobalState.board_cols, GlobalState.board_rows, GlobalState.bomb_percentage, GlobalState.board_wrap, "")
	assert_eq(base._board, prepared, "Start uses the background board")
	assert_eq(base._prepared_board, null, "Background slot is empty during the game")
	assert_eq(base._board.modulate, Color.WHITE, "Board is visible once the game starts")
	var live: CellBase = base._board.board_state[3][3]
	assert_true(base._board.can_process() and live.get_node("Area2D").can_process(),
		"Board and its cells take input once the game starts")

	base.free()


## A daily challenge picks its own board settings: it must not reuse a
## background board built for the menu's, must not overwrite the menu's
## seed, and a restart must replay the same daily.
func _test_daily_uses_its_own_settings() -> void:
	GlobalState.selected_board = 1  # Square
	GlobalState.board_cols = 8
	GlobalState.board_rows = 8
	GlobalState.board_wrap = false
	GlobalState.board_seed = ""
	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)
	var prepared: BaseBoard = await _wait_for_prepared(base)
	assert_true(prepared != null, "Menu builds a square background board")

	var date: String = "2026-11-11"
	base._main_menu._start_daily(date)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(date.hash())
	var expected_shape: int = rng.randi_range(0, MainMenu.BOARD_TYPE_NAMES.size() - 1)
	var expected_scene: String = base._board_scenes[expected_shape].resource_path
	assert_eq(base._board.scene_file_path, expected_scene, "Daily uses its own board shape, not the menu's")
	assert_true(base._board._wrap_mode, "Daily is a wrap board even though the menu is set to classic")
	assert_eq(base._camera._board_bounds, Rect2(), "Daily camera has no classic-mode bounds")
	assert_true(base._is_daily, "Game is flagged as the daily")
	assert_eq(base._board._seed, date, "Daily board is seeded with the date")
	assert_eq(GlobalState.board_seed, "", "Daily leaves the menu's seed untouched")

	var dims: Vector2i = Vector2i(base._board.cols, base._board.rows)
	var mines: int = base._board.mines
	base.restart_game()
	assert_eq(base._board.scene_file_path, expected_scene, "Restart keeps the daily's board shape")
	assert_eq(Vector2i(base._board.cols, base._board.rows), dims, "Restart keeps the daily's size")
	assert_eq(base._board.mines, mines, "Restart keeps the daily's mine count")
	assert_eq(base._board._seed, date, "Restart keeps the daily's seed")
	assert_true(base._is_daily, "Restarted daily is still the daily")

	# Losing the daily offers Continue: the same daily again, timer running.
	var continue_button: Button = base._final_screen.get_node("%Continue")
	base._board_gui._timer_start_msec = Time.get_ticks_msec() - 90_000  # 1:30 in
	base._board._handle_explosion(base._board.board_state[0][0])
	assert_true(base._final_screen.visible and continue_button.visible, "Lost daily offers Continue")
	continue_button.pressed.emit()
	assert_false(base._final_screen.visible, "Continue closes the end screen")
	assert_true(base._board_gui.visible, "Continue shows the HUD")
	assert_true(base._is_daily and base._board._seed == date, "Continue replays the same daily")
	assert_false(base._board._is_game_over, "Continue starts a fresh attempt")
	assert_true(base._board_gui.elapsed_seconds() >= 90, "Continue keeps the timer running")
	base.restart_game()
	assert_true(base._board_gui.elapsed_seconds() >= 90, "Restarting a daily from pause keeps the timer running")

	# A normal game afterwards: not a daily, no leaderboard on its end screen.
	base._reset()
	base._main_menu._on_start()
	assert_false(base._is_daily, "PLAY after a daily is not a daily")
	assert_eq(base._board._seed, "", "PLAY after a daily is not seeded")
	base._game_finished(true, 0.0)
	assert_false(base._final_screen._leaderboard_box.visible, "Non-daily win: no score submission")
	assert_false(base._final_screen._leaderboard_scroll.visible, "Non-daily win: no leaderboard")
	base._final_screen.game_finished(false, 10, 5, 2, false)
	assert_false(base._final_screen._leaderboard_box.visible, "Non-daily loss: no score submission")
	assert_false(base._final_screen.get_node("%Continue").visible, "Non-daily loss: no Continue")
	base._board_gui._timer_start_msec = Time.get_ticks_msec() - 90_000
	base.restart_game()
	assert_true(base._board_gui.elapsed_seconds() < 90 or not base._board_gui._timer_running,
		"Restarting a normal game resets the timer")

	base.free()


## Waits (bounded) until base.gd has a fully built background board.
func _wait_for_prepared(base: Node) -> BaseBoard:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var board: BaseBoard = base._prepared_board
		if board and board.is_built() and base._prepared_key == base._get_prepare_key():
			return board
	return null

