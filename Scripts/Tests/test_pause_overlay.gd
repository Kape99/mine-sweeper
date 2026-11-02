## Drives the real base.tscn through the pause overlay: Resume un-dims the
## board, Esc backs out of Settings to the pause overlay, Restart builds a
## fresh board, and Quit returns to the main menu.
extends TestCase

const BASE_SCENE: String = "res://Scenes/base.tscn"


func _ready() -> void:
	print("\n=== test_pause_overlay ===")
	await run()
	_report()


func run() -> void:
	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)
	await get_tree().process_frame
	var sm: ScreenManager = base.get_node("ScreenManager")

	base._load_game()
	var board: BaseBoard = base._board

	# Resume
	base._handle_back_button()
	assert_true(sm.get_current_screen() is PauseOverlay, "Back button opens the pause overlay")
	assert_true(is_equal_approx(board.modulate.a, 0.4), "Board is dimmed while paused")
	var camera: Camera2D = base.get_node("Camera")
	camera.offset = Vector2(300, 200)
	camera.zoom = Vector2(0.5, 0.5)
	var overlay_xform: Transform2D = sm.get_current_screen().get_global_transform_with_canvas()
	assert_eq(overlay_xform, Transform2D.IDENTITY,
		"Pause overlay is drawn in screen space (unaffected by camera pan/zoom)")
	camera.reset_view()
	(sm.get_current_screen() as PauseOverlay)._on_resume()
	assert_eq(sm.get_current_screen(), null, "Resume closes the pause overlay")
	assert_eq(board.modulate, Color.WHITE, "Resume un-dims the board")

	# Settings over pause, then back
	base._handle_back_button()
	var pause: PauseOverlay = sm.get_current_screen()
	pause._on_settings()
	assert_true(sm.get_current_screen() is SettingsMenu, "Pause > Settings shows the settings menu")
	base._handle_back_button()
	assert_eq(sm.get_current_screen(), pause, "Back from Settings restores the same pause overlay (no second one)")

	# Restart
	(sm.get_current_screen() as PauseOverlay)._on_restart()
	assert_true(base._board != null and is_instance_valid(base._board), "Restart creates a new board")
	assert_false(is_instance_valid(board), "Restart frees the old board")
	assert_eq(base._board.modulate, Color.WHITE, "Restarted board is not dimmed")

	# Quit to menu
	base._handle_back_button()
	(sm.get_current_screen() as PauseOverlay)._on_quit()
	assert_eq(base._board, null, "Quit to Menu clears the board reference")
	assert_true(sm.get_current_screen() is MainMenu, "Quit to Menu shows the main menu")

	base.free()
	BaseBoard.clear_pools()
