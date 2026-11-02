## Base class for all cell types (square, triangle, hexagon).
## Handles touch input and emits gameplay signals consumed by the board.
class_name CellBase
extends Container

## Maximum distance (in pixels) between touch-down and touch-up to register a tap.
const TAP_THRESHOLD: float = 15.0

## Time (ms) a finger must stay down to trigger a long-press defuse toggle.
const LONG_PRESS_THRESHOLD_MS: int = 400

## Haptic feedback duration (ms) on cell tap.
const TAP_VIBRATION_MS: int = 100

## Haptic feedback duration (ms) on long-press.
const LONG_PRESS_VIBRATION_MS: int = 50

## Visual highlight color for neighbors of a held revealed cell.
## Chosen to be clearly distinct from all scheme colors.
const NEIGHBOR_HIGHLIGHT_COLOR: Color = Color(0.0, 0.7, 1.0, 1.0)

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

## Emitted when the player taps this cell. [param cell] is self, [param p_nearby]
## is the mine-neighbor count (or -1 if mine).
signal cell_pressed(cell: CellBase, p_nearby: int)

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


func _ready() -> void:
	_bind_collision_shape()
	reset_state()


## Resets the cell to its pre-game unknown state. Used by object pools.
func reset_state() -> void:
	nearby = 0
	_cell_state = CellState.UNKNOWN
	_touch_pressed = false
	_long_press_triggered = false
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


func _process(_delta: float) -> void:
	if not _touch_pressed or _long_press_triggered:
		return
	var elapsed: int = Time.get_ticks_msec() - _touch_start_time
	if elapsed <= LONG_PRESS_THRESHOLD_MS:
		return
	_long_press_triggered = true
	if Settings.vibration_enabled:
		Input.vibrate_handheld(LONG_PRESS_VIBRATION_MS)
	if is_explored() and nearby > 0:
		cell_highlight_requested.emit(self)
	elif not is_explored():
		defuse()


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
		return

	if is_release_event:
		_touch_pressed = false
		var had_long_press: bool = _long_press_triggered
		_long_press_triggered = false
		if had_long_press:
			cell_highlight_cleared.emit()
			return
		if _touch_position.distance_to(event.position) < TAP_THRESHOLD:
			if Settings.vibration_enabled:
				Input.vibrate_handheld(TAP_VIBRATION_MS)
			cell_pressed.emit(self, nearby)
