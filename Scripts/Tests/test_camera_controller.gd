## Verifies CameraController applies its view itself: Camera2D's own
## per-frame update stays off (it forces a redraw every frame, defeating
## low-processor mode), yet offset and zoom changes still reach the screen.
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
