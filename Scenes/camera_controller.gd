class_name CameraController extends Camera2D

const MARGIN = 100

var touch_points : Dictionary = {}
var old_touch_points : Dictionary = {1: Vector2(0,0)}

var pinch_distance
var start_zoom



func _unhandled_input(event):	
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		touch_points[event.index] = get_viewport().get_screen_transform() * get_global_transform_with_canvas() * event.position
	else:
		touch_points.erase(event.index)
	
	if touch_points.size() == 2:
		var touch_points_position = touch_points.values()
		pinch_distance = touch_points_position[0].distance_to(touch_points_position[1])
		start_zoom = zoom
	
	if touch_points.size() < 2:
		pinch_distance = 0










func _handle_drag(event: InputEventScreenDrag):
	pass
	var point = get_viewport().get_screen_transform() * get_global_transform_with_canvas() * event.position
	if touch_points.size() == 1:
		offset -= event.relative / zoom.x

#	if touch_points.size() == 2:
#
#
#		# Find the index of the not moving
#		var pivot_index = 1 if event.index == 0 else 0 
#
#		# get the 3 point involved
#		var pivot_point : Vector2 = touch_points[pivot_index]
#		var previous_point : Vector2 = touch_points[event.index]
#		var new_point : Vector2 = point
#
#		var old_vector : Vector2 = previous_point - pivot_point
#		var new_vector : Vector2 = new_point - pivot_point
#
#		var scale = new_vector.x / old_vector.x
#
#		zoom.x = 1 / scale
#		zoom.y = 1 / scale
#		touch_points[event.index] = new_point
		

func set_limits(center, extent):
	pass
#	limit_left = center.x - extent.x - MARGIN
#	limit_top = center.y - extent.y - MARGIN
#	limit_right = center.x + extent.x + MARGIN
#	limit_bottom = center.y + extent.y + MARGIN
