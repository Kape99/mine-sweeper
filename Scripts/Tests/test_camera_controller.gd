## Verifies CameraController applies its view itself: Camera2D's own
## per-frame update stays off (it forces a redraw every frame, defeating
## low-processor mode), yet offset and zoom changes still reach the screen.
## Also checks one drag pans exactly once even when touch emulation sends
## it as both a screen drag and a mouse motion, and that the safe-area
## margins are measured against the window, not the whole desktop.
extends TestCase


func _ready() -> void:
	print("\n=== test_camera_controller ===")
	await run()
	_report()


func run() -> void:
	var camera: CameraController = load("res://Scripts/GUI/camera_controller.gd").new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	# make_current() turns Camera2D's own update back on; the controller
	# switches it off again in its next _process. process_frame fires
	# before nodes' _process, so wait two frames.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(camera.is_processing_internal(), "Camera2D's per-frame update is off")

	camera.offset = Vector2(120, -40)
	await get_tree().process_frame
	assert_eq(get_viewport().canvas_transform.origin, Vector2(-120, 40), "Offset change is applied")

	camera.zoom = Vector2(2, 2)
	await get_tree().process_frame
	assert_eq(get_viewport().canvas_transform.get_scale(), Vector2(2, 2), "Zoom change is applied")

	camera.reset_view()
	await get_tree().process_frame
	assert_eq(get_viewport().canvas_transform, Transform2D.IDENTITY, "reset_view is applied")
	assert_false(camera.is_processing_internal(), "Per-frame update stays off")
	camera.free()

	_test_drag_pans_once()
	_test_safe_area_insets()


func _test_drag_pans_once() -> void:
	var camera: CameraController = load("res://Scripts/GUI/camera_controller.gd").new()
	add_child(camera)

	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(100, 100)
	camera._unhandled_input(touch)

	# With touch emulation, one physical drag arrives as both events.
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(130, 100)
	drag.relative = Vector2(30, 0)
	camera._unhandled_input(drag)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = Vector2(130, 100)
	motion.relative = Vector2(30, 0)
	camera._unhandled_input(motion)
	assert_eq(camera.offset, Vector2(-30, 0), "A touch drag mirrored as mouse motion pans only once")

	touch.pressed = false
	camera._unhandled_input(touch)
	camera._unhandled_input(motion)
	assert_eq(camera.offset, Vector2(-60, 0), "A plain mouse drag (no touch down) still pans")
	camera.free()


func _test_safe_area_insets() -> void:
	var screen: GDScript = load("res://Scenes/Screen.gd")
	var none: Dictionary = {"top": 0, "left": 0, "bottom": 0, "right": 0}

	# Desktop, window on a second monitor starting at x = 1920; the safe
	# area reported is the first monitor's.
	assert_eq(screen.safe_area_insets(Rect2i(0, 0, 1920, 1200), Rect2i(1920 + 300, 100, 683, 1040)), none,
		"Window on another monitor gets no safe-area inset")
	# Desktop, window fully inside the safe area of its own monitor.
	assert_eq(screen.safe_area_insets(Rect2i(1920, 0, 1920, 1080), Rect2i(2200, 20, 480, 800)), none,
		"Window inside the safe area gets no inset")
	# Phone: full-screen window, notch at the top, gesture bar at the bottom.
	assert_eq(screen.safe_area_insets(Rect2i(0, 90, 1080, 2190), Rect2i(0, 0, 1080, 2340)),
		{"top": 90, "left": 0, "bottom": 60, "right": 0},
		"Phone notch and gesture bar become top and bottom insets")
