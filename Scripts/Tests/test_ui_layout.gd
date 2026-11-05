## Verifies the screens are laid out on the whole viewport and centered,
## and that during a game nothing but the HUD's own widgets blocks taps
## meant for the board. (Simulated clicks don't reach the GUI or physics
## picking headlessly, so blocking is checked the way Godot decides it:
## a visible Control with MOUSE_FILTER_STOP under the point consumes it.)
extends TestCase

const BASE_SCENE: String = "res://Scenes/base.tscn"

## Allowed distance (px) between a widget's center and the screen's.
const CENTER_TOLERANCE: float = 2.0


func _ready() -> void:
	print("\n=== test_ui_layout ===")
	await run()
	_report()


func run() -> void:
	GlobalState.selected_board = 1
	GlobalState.board_cols = 10
	GlobalState.board_rows = 10
	GlobalState.board_wrap = true
	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)
	await _settle()
	var screen: Rect2 = get_viewport().get_visible_rect()

	var gui_root: Control = base.get_node("GUI/Screen")
	assert_eq(gui_root.get_global_rect(), screen, "GUI/Screen covers the whole viewport")

	base._load_game()
	base._board._on_cell_pressed(base._board.board_state[5][5], 0)
	await _settle()
	var hud: Control = base.get_node("GUI/Screen/BoardGUI")
	assert_true(hud.visible and hud.get_global_rect() == screen, "HUD covers the whole viewport")
	_assert_centered_x(hud.get_node("ColorRect"), screen, "HUD score box")
	_assert_centered_x(hud.get_node("DefuseButton"), screen, "HUD defuse button")
	for button: String in ["PauseButton", "Reset"]:
		assert_true(screen.encloses(hud.get_node(button).get_global_rect()), "HUD %s is fully on screen" % button)

	var blockers: Dictionary = _blocking_controls(base, screen)
	var stray: Array[String] = []
	for control: Control in blockers:
		if not hud.is_ancestor_of(control):
			stray.append(str(base.get_path_to(control)))
	assert_eq(stray, [] as Array[String], "During a game only HUD widgets block taps on the board")
	assert_true(blockers.values().reduce(func(a: int, b: int) -> int: return a + b, 0) < 0.1 * _sample_count(screen),
		"HUD widgets block less than 10% of the screen")

	base._handle_back_button()
	await _settle()
	var pause: Control = base.get_node("ScreenManager").get_current_screen()
	assert_eq(pause.get_node("Background").get_global_rect(), screen, "Pause background covers the screen")
	_assert_centered(_first_child_of_type(pause, "VBoxContainer"), screen, "Pause buttons")

	(pause as PauseOverlay)._on_settings()
	await _settle()
	var settings: Control = base.get_node("ScreenManager").get_current_screen()
	assert_eq(settings.get_node("Background").get_global_rect(), screen, "Settings background covers the screen")
	_assert_centered(_first_child_of_type(settings, "VBoxContainer"), screen, "Settings panel")
	assert_true(screen.encloses(_first_child_of_type(settings, "VBoxContainer").get_global_rect()),
		"Settings panel is fully on screen")

	base._handle_back_button()
	base._handle_back_button()
	base._game_finished(false, 0.0)
	await _settle()
	assert_false((hud as BoardGUI)._timer_running, "Timer stops at game over")
	var recap: Label = base.get_node("GUI/Screen/FinalScreen/BlurPanel/CenterContainer/VBoxContainer/RecapLabel")
	assert_true(recap.text.contains("mines found"), "End screen recaps mines found and time")
	var final_screen: Control = base.get_node("GUI/Screen/FinalScreen")
	assert_eq(final_screen.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"End screen lets input through outside its panel (board stays pannable)")
	var panel: Control = base.get_node("GUI/Screen/FinalScreen/BlurPanel")
	_assert_centered_x(panel, screen, "End screen panel")
	assert_true(panel.get_global_rect().end.y < screen.get_center().y,
		"End screen panel sits in the upper half, leaving the board visible")
	var back: Control = base.get_node("%BackToMenu")
	assert_true(absf(back.get_global_rect().get_center().x - panel.get_global_rect().get_center().x) <= CENTER_TOLERANCE
		and panel.get_global_rect().encloses(back.get_global_rect()),
		"End screen 'Back to Menu' is centered inside the panel")

	# The camera frames the board centered when a game starts.
	for wrap: bool in [false, true]:
		base._reset()
		GlobalState.board_wrap = wrap
		base._load_game()
		await _settle()
		var tile: Control = base._board._tile
		var on_screen: Rect2 = tile.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, tile.size)
		var offset: Vector2 = on_screen.get_center() - screen.get_center()
		assert_true(offset.length() <= CENTER_TOLERANCE,
			"%s board is centered on screen at game start (off by %s)" % ["Wrap" if wrap else "Classic", offset])

	base.free()
	BaseBoard.clear_pools()


func _settle() -> void:
	# Screen transitions are short tweens; layout settles within a frame.
	await wait_wall_ms(400)


func _assert_centered(control: Control, screen: Rect2, what: String) -> void:
	var offset: Vector2 = control.get_global_rect().get_center() - screen.get_center()
	assert_true(absf(offset.x) <= CENTER_TOLERANCE and absf(offset.y) <= CENTER_TOLERANCE,
		"%s is centered (off by %s)" % [what, offset])


func _assert_centered_x(control: Control, screen: Rect2, what: String) -> void:
	var offset: float = control.get_global_rect().get_center().x - screen.get_center().x
	assert_true(absf(offset) <= CENTER_TOLERANCE, "%s is centered horizontally (off by %.1f)" % [what, offset])


func _first_child_of_type(root: Node, type: String) -> Control:
	return root.find_children("*", type, true, false)[0]


## Sample points every 10 px across the screen.
func _sample_points(screen: Rect2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for y: int in range(5, int(screen.size.y), 10):
		for x: int in range(5, int(screen.size.x), 10):
			points.append(Vector2(x, y))
	return points


func _sample_count(screen: Rect2) -> int:
	return _sample_points(screen).size()


## Visible STOP controls under any sample point, mapped to how many sample
## points each one covers.
func _blocking_controls(root: Node, screen: Rect2) -> Dictionary:
	var rects: Dictionary = {}
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node
		if control.mouse_filter != Control.MOUSE_FILTER_STOP or not control.is_visible_in_tree():
			continue
		if control.get_global_transform_with_canvas() == Transform2D() and control.size == Vector2.ZERO:
			continue
		rects[control] = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	var hits: Dictionary = {}
	for point: Vector2 in _sample_points(screen):
		for control: Control in rects:
			if (rects[control] as Rect2).has_point(point):
				hits[control] = hits.get(control, 0) + 1
	return hits
