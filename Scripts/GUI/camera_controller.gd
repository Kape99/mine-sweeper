## Touch-friendly camera controller supporting single-finger pan, two-finger pinch-zoom,
## and mouse wheel zoom. Zoom is clamped between [member MIN_ZOOM] and [member MAX_ZOOM].
## Pan offset is clamped when [member _board_bounds] is set (classic mode),
## unconstrained otherwise (wrap mode).
class_name CameraController
extends Camera2D

## Minimum zoom level (furthest out).
const MIN_ZOOM: Vector2 = Vector2(0.5, 0.5)

## Maximum zoom level (closest in).
const MAX_ZOOM: Vector2 = Vector2(2.0, 2.0)

## Zoom step multiplier for mouse wheel input.
const WHEEL_ZOOM_STEP: float = 1.05

## Extra padding (pixels) around the board bounds for panning limit.
const PAN_MARGIN: float = 100.0

## Active touch points indexed by finger index.
var _touch_points: Dictionary = {}

## The view last applied to the viewport (see [method _process]).
var _applied_view: Array = []


func _ready() -> void:
	# Camera2D re-applies its transform every frame, which counts as a
	# change and forces a full redraw every frame — defeating the
	# project's low-processor mode (redraw only when something changed).
	# Apply it ourselves, only when the view actually changes.
	set_process_internal(false)


func _process(_delta: float) -> void:
	if is_processing_internal():
		set_process_internal(false)  # Camera2D may re-enable it, e.g. on re-entering the tree
	var view: Array = [offset, zoom, global_position, get_viewport_rect().size, is_current()]
	if view != _applied_view:
		_applied_view = view
		force_update_scroll()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_wheel(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_drag(event as InputEventMouseMotion)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
	else:
		_touch_points.erase(event.index)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touch_points.size() == 1:
		offset -= event.relative / zoom.x
		_clamp_offset()
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
		_clamp_offset()
		_touch_points[event.index] = new_point


## Mouse-drag panning — the desktop equivalent of the one-finger touch
## pan. A drag moves beyond the tap threshold, so it never triggers a
## cell tap on release.
func _handle_mouse_drag(event: InputEventMouseMotion) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		offset -= event.relative / zoom.x
		_clamp_offset()


func _handle_mouse_wheel(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom = (zoom * WHEEL_ZOOM_STEP).clamp(MIN_ZOOM, MAX_ZOOM)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom = (zoom / WHEEL_ZOOM_STEP).clamp(MIN_ZOOM, MAX_ZOOM)
	_clamp_offset()


## Bounding rect of the board in world space. Empty rect means unconstrained.
var _board_bounds: Rect2 = Rect2()


## Sets the board bounds and centers the camera on it. Call after board
## instantiation in classic (non-wrapping) mode.
func set_board_bounds(board_position: Vector2, board_size: Vector2) -> void:
	_board_bounds = Rect2(
		board_position - Vector2(PAN_MARGIN, PAN_MARGIN),
		board_size + Vector2(PAN_MARGIN * 2.0, PAN_MARGIN * 2.0)
	)
	offset = _board_bounds.get_center()
	zoom = Vector2.ONE


## Resets camera offset, zoom, and bounds to default values.
func reset_view() -> void:
	offset = Vector2.ZERO
	zoom = Vector2.ONE
	_board_bounds = Rect2()


## Constrains [member offset] so the camera stays within [member _board_bounds].
func _clamp_offset() -> void:
	if _board_bounds.size == Vector2.ZERO:
		return
	var half_view: Vector2 = get_viewport_rect().size / (2.0 * zoom)
	var min_offset: Vector2 = _board_bounds.position + half_view
	var max_offset: Vector2 = _board_bounds.end - half_view
	# If board is smaller than viewport at current zoom, center it
	if min_offset.x > max_offset.x:
		offset.x = _board_bounds.get_center().x
	else:
		offset.x = clampf(offset.x, min_offset.x, max_offset.x)
	if min_offset.y > max_offset.y:
		offset.y = _board_bounds.get_center().y
	else:
		offset.y = clampf(offset.y, min_offset.y, max_offset.y)