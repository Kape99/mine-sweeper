class_name CameraController extends Camera2D

var touch_points: Dictionary = {}


func _unhandled_input(event):
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom *= 1.05
		zoom = zoom.clamp(Vector2(.5, .5), Vector2(2, 2))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom *= .95
		zoom = zoom.clamp(Vector2(.5, .5), Vector2(2, 2))


func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		touch_points[event.index] = event.position
	else:
		touch_points.erase(event.index)


func _handle_drag(event: InputEventScreenDrag):
	if touch_points.size() == 1:
		offset -= event.relative / zoom.x
		touch_points[event.index] = event.position

	if touch_points.size() == 2:
		# Find the index of the not moving
		var pivot_index = 1 if event.index == 0 else 0

		# get the 3 point involved
		var pivot_point: Vector2 = touch_points[pivot_index]
		var old_point: Vector2 = touch_points[event.index]
		var new_point: Vector2 = event.position

		var drag_vector: Vector2 = new_point - old_point

		var old_vector: Vector2 = old_point - pivot_point
		var new_vector: Vector2 = new_point - pivot_point

		offset -= (drag_vector / 2) / zoom.x

		var delta_scale = new_vector.length() / old_vector.length()
		zoom *= delta_scale
		zoom = zoom.clamp(Vector2i(.5, .5), Vector2i(2, 2))
		touch_points[event.index] = new_point


func reset_view():
	offset = Vector2(0, 0)
	zoom = Vector2(1, 1)
