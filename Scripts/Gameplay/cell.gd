## Base class for all cell types (square, triangle, hexagon).
## Handles touch input and emits gameplay signals consumed by the board.
class_name CellBase
extends Container

## Maximum distance (in pixels) between touch-down and touch-up to register a tap.
## Read from Settings.tap_threshold at runtime.
const TAP_THRESHOLD: float = 15.0

## Time (ms) a finger must stay down to trigger a long-press defuse toggle.
## Read from Settings.long_press_threshold_ms at runtime.
const LONG_PRESS_THRESHOLD_MS: int = 400

## Visual highlight color for neighbors of a held revealed cell.
## Chosen to be clearly distinct from all scheme colors.
const NEIGHBOR_HIGHLIGHT_COLOR: Color = Color(0.0, 0.7, 1.0, 1.0)

## Icon color of a flagged cell revealed at game over as a mistake (no
## mine under it): the flag turns red, the cell fill stays untouched.
const WRONG_DEFUSE_COLOR: Color = Color.RED

## How much larger the tap-collision shape is than the visible fill shape,
## expressed as a uniform scale from the fill polygon's centroid. Keeps the
## touch target slightly bigger than what's drawn without hand-authoring a
## second polygon per cell shape.
const COLLISION_SCALE: float = 1.1

const FLAG_ICON: Texture2D = preload("res://Asset/Icons/flag.svg")
const MINE_ICON: Texture2D = preload("res://Asset/Icons/mine.svg")

enum CellState { UNKNOWN, DEFUSED, EXPLORED }

## Current visual/interaction state of the cell.
var _cell_state: CellState = CellState.UNKNOWN

@onready var _cell_text: Label = $Area2D/Node2D/Content/Label
@onready var _cell_icon: TextureRect = $Area2D/Node2D/Content/TextureRect
@onready var _cell_triangle: Polygon2D = $Area2D/Polygon2D
@onready var _cell_collision: CollisionPolygon2D = $Area2D/CollisionPolygon2D

## Emitted on every single tap (also the first tap of a double tap); the
## board decides what it does. [param cell] is self, [param p_nearby]
## is the mine-neighbor count (or -1 if mine).
signal cell_pressed(cell: CellBase, p_nearby: int)

## Emitted on a double tap. A double tap always opens the cell, even in
## defuse mode or when flagged.
signal cell_open_requested(cell: CellBase)

## Emitted when a non-mine cell transitions to explored state.
signal cell_explored(cell: CellBase)

## Emitted when the cell is flagged or unflagged.
## [param is_defused] is [code]true[/code] when entering defuse state.
signal cell_defused(cell: CellBase, is_defused: bool)

## Emitted when a mine cell is explored (game over trigger).
signal cell_exploded(cell: CellBase)

## Emitted when a revealed cell with nearby mines is held to highlight neighbors.
signal cell_highlight_requested(cell: CellBase)

## Emitted when the finger is lifted after a long-press highlight.
signal cell_highlight_cleared

## Mine-neighbor count for this cell.[br]
## [code]-1[/code] means this cell is a mine.[br]
## Positive values represent how many adjacent mines exist.[br]
## Use [method mark_as_mine] and [method increment_nearby] to modify — do not set directly.
var nearby: int = 0

## Grid coordinate of this cell (column, row).
var coord: Vector2i

## Screen position recorded on touch-down, used for tap/long-press detection.
var _touch_position: Vector2

## Whether the player is currently holding this cell.
var _touch_pressed: bool = false

## Time (ms) when the current hold started.
var _touch_start_time: int = 0

## True if the long-press action already fired for the current hold.
var _long_press_triggered: bool = false

## True if the finger moved beyond TAP_THRESHOLD while holding.
var _touch_dragged: bool = false

## Time (ms) of the first tap in a potential double-tap sequence.
var _pending_tap_time: int = 0

## Screen position of the first tap in a potential double-tap sequence.
var _pending_tap_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_bind_collision_shape()
	reset_state()


## Resets the cell to its pre-game unknown state. Used by object pools.
func reset_state() -> void:
	nearby = 0
	_cell_state = CellState.UNKNOWN
	_touch_pressed = false
	_long_press_triggered = false
	_pending_tap_time = 0
	set_display(GlobalState.secondary_color, GlobalState.main_color)
	_cell_icon.texture = null
	_cell_text.text = ""


## Derives the tap-collision polygon from the visible fill polygon by
## scaling it uniformly around its centroid. Keeps the two shapes in sync
## from a single source of truth ([member _cell_triangle].polygon) instead
## of a hand-authored duplicate array per cell scene.
func _bind_collision_shape() -> void:
	var fill: PackedVector2Array = _cell_triangle.polygon
	if fill.is_empty():
		return
	var centroid: Vector2 = Vector2.ZERO
	for point: Vector2 in fill:
		centroid += point
	centroid /= fill.size()

	var scaled: PackedVector2Array = PackedVector2Array()
	scaled.resize(fill.size())
	for i: int in fill.size():
		scaled[i] = centroid + (fill[i] - centroid) * COLLISION_SCALE
	_cell_collision.polygon = scaled


## Permanently marks this cell as a mine. Irreversible.
func mark_as_mine() -> void:
	nearby = -1


## Increments the neighbor mine count by one. No-op if cell is already a mine.
func increment_nearby() -> void:
	if nearby != -1:
		nearby += 1


## Returns [code]true[/code] if this cell is a mine.
func is_mine() -> bool:
	return nearby == -1


## Attempt to toggle defuse (flag) on this cell.
func defuse() -> void:
	if _cell_state == CellState.EXPLORED:
		return
	if _cell_state == CellState.UNKNOWN:
		_cell_state = CellState.DEFUSED
		set_display(GlobalState.secondary_color, GlobalState.main_color, FLAG_ICON)
		cell_defused.emit(self, true)
	else:
		_cell_state = CellState.UNKNOWN
		set_display(GlobalState.secondary_color, GlobalState.main_color)
		cell_defused.emit(self, false)


## Attempt to explore (reveal) this cell.
func explore() -> void:
	if _cell_state != CellState.UNKNOWN:
		return
	_cell_state = CellState.EXPLORED
	if is_mine():
		set_display(Color.RED, Color.WHITE)
		set_icon(MINE_ICON, Color.WHITE)
		cell_exploded.emit(self)
	else:
		var text: String = str(nearby) if nearby > 0 else ""
		set_display(GlobalState.main_color, GlobalState.secondary_color, null, text)
		cell_explored.emit(self)


## Returns [code]true[/code] if this cell has already been explored.
func is_explored() -> bool:
	return _cell_state == CellState.EXPLORED


## Returns [code]true[/code] if this cell is currently flagged.
func is_defused() -> bool:
	return _cell_state == CellState.DEFUSED


## Updates the visual appearance of this cell.
func set_display(bg_color: Color, content_color: Color, icon: Texture2D = null, text: String = "") -> void:
	_cell_triangle.modulate = bg_color
	_cell_text.modulate = content_color
	_cell_icon.modulate = content_color
	_cell_icon.texture = icon
	_cell_text.text = text


## Marks a flagged cell as a mistake at game over: it held no mine. The
## flag icon turns red; the cell fill stays as it is. No-op on any other
## cell (correctly flagged mines stay as they are).
func mark_wrongly_defused() -> void:
	if _cell_state == CellState.DEFUSED and not is_mine():
		set_icon(FLAG_ICON, WRONG_DEFUSE_COLOR)


## Temporarily highlights this cell as a neighbor of a held revealed cell.
func set_neighbor_highlight(enabled: bool) -> void:
	if enabled:
		_cell_triangle.modulate = NEIGHBOR_HIGHLIGHT_COLOR
	else:
		# Restore colors based on current state without touching icon/text.
		match _cell_state:
			CellState.DEFUSED:
				_cell_triangle.modulate = GlobalState.secondary_color
			CellState.EXPLORED:
				_cell_triangle.modulate = Color.RED if is_mine() else GlobalState.main_color
			_:
				_cell_triangle.modulate = GlobalState.secondary_color


## Overrides only the icon texture and its color. Used when the icon color
## differs from the default content color (e.g. mine icon on explosion).
func set_icon(icon: Texture2D, icon_color: Color) -> void:
	_cell_icon.texture = icon
	_cell_icon.modulate = icon_color


# -- Read-only visual state, used by BoardCopyRenderer to draw copies -----

## Current fill color of the cell shape (including highlights).
func get_fill_color() -> Color:
	return _cell_triangle.color * _cell_triangle.modulate


## Text currently shown (neighbor count), or empty.
func get_text() -> String:
	return _cell_text.text


## Modulate applied to the text.
func get_text_modulate() -> Color:
	return _cell_text.modulate


## The label's current rect in its parent ("Content") space. Its size can
## grow with the text, so it's read per draw rather than cached.
func get_text_rect() -> Rect2:
	return Rect2(_cell_text.position, _cell_text.size)


## Icon currently shown (flag / mine), or null.
func get_icon() -> Texture2D:
	return _cell_icon.texture


## Modulate applied to the icon.
func get_icon_modulate() -> Color:
	return _cell_icon.modulate


## Describes how this cell scene lays out its visuals, relative to the
## cell. Identical for every instance of the same scene, so callers cache
## it per [member Node.scene_file_path]. The cell must be inside the tree.
## Control positions are returned raw (local to their parent) because the
## renderer must apply Control pixel snapping to them itself.
func get_render_layout() -> Dictionary:
	var to_cell: Transform2D = get_global_transform().affine_inverse()
	var poly_xform: Transform2D = to_cell * _cell_triangle.get_global_transform()
	var polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _cell_triangle.polygon:
		polygon.append(poly_xform * (point + _cell_triangle.offset))
	var content: Control = _cell_text.get_parent() as Control
	return {
		"polygon": polygon,
		# Content's parent is a Node2D (not snapped); Content itself is a Control.
		"content_parent_xform": to_cell * (content.get_parent() as CanvasItem).get_global_transform(),
		"content_position": content.position,
		"font": _cell_text.get_theme_font("font"),
		"font_size": _cell_text.get_theme_font_size("font_size"),
		"font_color": _cell_text.get_theme_color("font_color"),
		"icon_position": _cell_icon.position,
		"icon_size": _cell_icon.size,
		"icon_stretch": _cell_icon.stretch_mode,
	}


func _process(_delta: float) -> void:
	if not _touch_pressed or _long_press_triggered:
		return
	var elapsed: int = Time.get_ticks_msec() - _touch_start_time
	if elapsed <= Settings.long_press_threshold_ms:
		return
	_long_press_triggered = true
	_pending_tap_time = 0
	if is_explored() and nearby > 0:
		cell_highlight_requested.emit(self)


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, _local_shape: Object = null) -> void:
	var is_press_event: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	)
	var is_release_event: bool = (
		(event is InputEventScreenTouch and not event.pressed)
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
	)

	if is_press_event:
		_touch_pressed = true
		_touch_start_time = Time.get_ticks_msec()
		_touch_position = event.position
		_long_press_triggered = false
		_touch_dragged = false
		# Clear a stale pending tap when a new press begins.
		if _pending_tap_time > 0:
			var now: int = Time.get_ticks_msec()
			if now - _pending_tap_time > Settings.double_tap_window_ms:
				_pending_tap_time = 0
		get_viewport().set_input_as_handled()
		return

	var is_drag_event: bool = event is InputEventScreenDrag

	if is_drag_event and _touch_pressed:
		if _touch_position.distance_to(event.position) > Settings.tap_threshold:
			_touch_dragged = true
			_pending_tap_time = 0
		get_viewport().set_input_as_handled()
		return

	# One physical tap arrives twice — as a touch AND a mouse event — because
	# of input pointing emulation (emulate_touch_from_mouse in project.godot,
	# emulate_mouse_from_touch by default). Only the first release of a press
	# counts; the duplicate would toggle defuse back or fake a double tap.
	if is_release_event and _touch_pressed:
		_touch_pressed = false
		var had_long_press: bool = _long_press_triggered
		var was_dragged: bool = _touch_dragged
		_long_press_triggered = false
		_touch_dragged = false
		var within_threshold: bool = _touch_position.distance_to(event.position) < Settings.tap_threshold
		if had_long_press:
			if is_explored():
				cell_highlight_cleared.emit()
			elif not was_dragged and within_threshold:
				defuse()
			get_viewport().set_input_as_handled()
			return
		if within_threshold:
			var now: int = Time.get_ticks_msec()
			var is_double_tap: bool = (
				_pending_tap_time > 0
				and now - _pending_tap_time <= Settings.double_tap_window_ms
				and _pending_tap_position.distance_to(event.position) < Settings.tap_threshold
			)
			if is_double_tap:
				# Double tap always opens the cell, in any mode.
				_pending_tap_time = 0
				cell_open_requested.emit(self)
			else:
				# Remember this tap; a second one within the window opens.
				_pending_tap_time = now
				_pending_tap_position = event.position
				# The board decides what a single tap does (open or flag, by
				# mode) so that logic lives in one place:
				# BaseBoard._on_cell_pressed.
				cell_pressed.emit(self, nearby)
			get_viewport().set_input_as_handled()
