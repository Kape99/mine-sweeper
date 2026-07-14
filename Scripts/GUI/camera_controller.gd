## Touch-friendly camera controller supporting single-finger pan, two-finger pinch-zoom,
## and mouse wheel zoom. Zoom is clamped between [member MIN_ZOOM] and [member MAX_ZOOM].
class_name CameraController
extends Camera2D

## Minimum zoom level (furthest out).
const MIN_ZOOM: Vector2 = Vector2(0.5, 0.5)

## Maximum zoom level (closest in).
const MAX_ZOOM: Vector2 = Vector2(2.0, 2.0)

## Zoom step multiplier for mouse wheel input.
const WHEEL_ZOOM_STEP: float = 1.05

## Active touch points indexed by finger index.
var _touch_points: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_wheel(event as InputEventMouseButton)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
	else:
		_touch_points.erase(event.index)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touch_points.size() == 1:
		offset -= event.relative / zoom.x
		_touch_points[event.index] = event.position

	elif _touch_points.size() == 2:
		var pivot_index: int = 1 if event.index == 0 else 0
		var old_point: Vector2 = _touch_points[event.index]
		var new_point: Vector2 = event.position
		var pivot_point: Vector2 = _touch_points[pivot_index]

		var drag_vector: Vector2 = new_point - old_point
		var old_vector: Vector2 = old_point - pivot_point
		var new_vector: Vector2 = new_point - pivot_point

		offset -= (drag_vector / 2.0) / zoom.x

		var delta_scale: float = new_vector.length() / old_vector.length()
		zoom = (zoom * delta_scale).clamp(MIN_ZOOM, MAX_ZOOM)
		_touch_points[event.index] = new_point


func _handle_mouse_wheel(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom = (zoom * WHEEL_ZOOM_STEP).clamp(MIN_ZOOM, MAX_ZOOM)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom = (zoom / WHEEL_ZOOM_STEP).clamp(MIN_ZOOM, MAX_ZOOM)


## Resets camera offset and zoom to default values.
func reset_view() -> void:
	offset = Vector2.ZERO
	zoom = Vector2.ONE
