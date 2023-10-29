class_name CameraController extends Camera2D

const MARGIN = 100

var touch_points: Dictionary = {}


func _unhandled_input(event):
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		touch_points[event.index] = event.position
	else:
		touch_points.erase(event.index)


func _handle_drag(event: InputEventScreenDrag):
	if touch_points.size() == 1:
		offset -= event.relative / zoom.x

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

		var delta_pos = drag_vector.dot(new_vector) / new_vector.length() * new_vector.normalized()

		print(delta_pos)
		offset -= drag_vector / 2

		var delta_scale = new_vector.length() / old_vector.length()
		print(delta_scale)
		zoom *= delta_scale

		touch_points[event.index] = new_point


func set_limits(center, extent):
	pass
#	limit_left = center.x - extent.x - MARGIN
#	limit_top = center.y - extent.y - MARGIN
#	limit_right = center.x + extent.x + MARGIN
#	limit_bottom = center.y + extent.y + MARGIN
