## Input on the end screen's leaderboard must not reach the game behind it:
## scrolling the list (touch drag, mouse drag or wheel) must not pan or zoom
## the camera, and a tap on it must not open a cell.
extends TestCase

const BASE_SCENE: String = "res://Scenes/base.tscn"
const ENTRY_SCENE: String = "res://Scenes/Menu/entry.tscn"


func _ready() -> void:
	print("\n=== test_final_screen_input ===")
	await run()
	_report()


func run() -> void:
	var base: Node = load(BASE_SCENE).instantiate()
	add_child(base)
	await get_tree().process_frame
	base._load_game(GlobalState.selected_board, GlobalState.board_cols, GlobalState.board_rows, GlobalState.bomb_percentage, true, "")
	base._board._on_cell_pressed(base._board.board_state[5][5], 0)
	base._game_finished(true, 0.0)

	# Show the daily leaderboard with enough rows to scroll, without Talo.
	var final_screen: Control = base._final_screen
	var scroll: ScrollContainer = final_screen._leaderboard_scroll
	final_screen._leaderboard_box.visible = true
	scroll.visible = true
	for child: Node in final_screen._leaderboard.get_children():
		child.free()
	for i: int in 30:
		var entry: Entry = load(ENTRY_SCENE).instantiate()
		final_screen._leaderboard.add_child(entry)
		entry.set_entry("player%d" % i, str(60 + i))
	await _frames(3)

	var camera: CameraController = base._camera
	var start_offset: Vector2 = camera.offset
	var start_zoom: Vector2 = camera.zoom
	var center: Vector2 = scroll.get_global_rect().get_center()
	assert_gt(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, 0.0, "Leaderboard has rows to scroll")

	# Hover first: the GUI only routes clicks once it knows what's under
	# the pointer.
	_push_mouse_motion(center, Vector2.ZERO, 0)

	# Touch drag up the list (with the mouse events touch emulation adds).
	_push_touch(center, true)
	for step: int in 6:
		_push_drag(center + Vector2(0, -10 * (step + 1)), Vector2(0, -10))
	_push_touch(center + Vector2(0, -60), false)
	await _frames(2)
	assert_eq(camera.offset, start_offset, "Touch-dragging the leaderboard doesn't pan the board")

	# Mouse wheel over the list, including past its end.
	for i: int in 40:
		_push_wheel(center, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(2)
	assert_eq(camera.zoom, start_zoom, "Wheel over the leaderboard doesn't zoom the board")
	assert_gt(scroll.scroll_vertical, 0.0, "Wheel scrolls the leaderboard")

	# Wheel elsewhere on the panel (over the title, not the list).
	var title: Control = final_screen._final_title
	_push_mouse_motion(title.get_global_rect().get_center(), Vector2.ZERO, 0)
	for i: int in 5:
		_push_wheel(title.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	await _frames(2)
	assert_eq(camera.zoom, start_zoom, "Wheel over the end-screen panel doesn't zoom the board")

	# A trackpad pan over the list.
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.position = center
	pan.delta = Vector2(0, 50)
	_push(pan)
	await _frames(2)
	assert_eq(camera.offset, start_offset, "Trackpad pan over the leaderboard doesn't pan the board")
	assert_eq(camera.zoom, start_zoom, "Trackpad pan over the leaderboard doesn't zoom the board")

	# Mouse drag over the list (desktop / web).
	_push_mouse_motion(center, Vector2.ZERO, 0)
	_push_mouse_button(center, true)
	_push_mouse_motion(center + Vector2(0, -50), Vector2(0, -50), MOUSE_BUTTON_MASK_LEFT)
	_push_mouse_button(center + Vector2(0, -50), false)
	await _frames(2)
	assert_eq(camera.offset, start_offset, "Mouse-dragging the leaderboard doesn't pan the board")

	base.free()
	BaseBoard.clear_pools()


## Pushes [param event] in viewport coordinates. (Headless, the window is
## tiny, so window coordinates would land off-screen.) Each event is pushed
## the way a device delivers it; touch emulation's extra mouse events are
## pushed explicitly by the helpers below.
func _push(event: InputEvent) -> void:
	get_viewport().push_input(event, true)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _push_touch(pos: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = pos
	touch.pressed = pressed
	_push(touch)
	_push_mouse_button(pos, pressed)


func _push_drag(pos: Vector2, relative: Vector2) -> void:
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = pos
	drag.relative = relative
	_push(drag)
	_push_mouse_motion(pos, relative, MOUSE_BUTTON_MASK_LEFT)


func _push_mouse_button(pos: Vector2, pressed: bool) -> void:
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = pos
	mb.global_position = pos
	mb.pressed = pressed
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_push(mb)


func _push_mouse_motion(pos: Vector2, relative: Vector2, mask: int) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.relative = relative
	motion.button_mask = mask
	_push(motion)


func _push_wheel(pos: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = button
		mb.position = pos
		mb.global_position = pos
		mb.pressed = pressed
		mb.factor = 1.0
		_push(mb)
