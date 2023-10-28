class_name CameraController extends Camera2D

const MARGIN = 100


func _unhandled_input(event):
	if event is InputEventScreenDrag:
		position -= event.relative
	if event is InputEventMagnifyGesture:
		zoom *= event.factor


func set_limits(center, extent):
	limit_left = center.x - extent.x - MARGIN
	limit_top = center.y - extent.y - MARGIN
	limit_right = center.x + extent.x + MARGIN
	limit_bottom = center.y + extent.y + MARGIN
