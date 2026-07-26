## Base class for all cell types (square, triangle, hexagon).
## Manages cell state through [StateMachine], handles touch input, and emits
## gameplay signals consumed by the board.
class_name CellBase
extends Container

## Maximum distance (in pixels) between touch-down and touch-up to register a tap.
const TAP_THRESHOLD: float = 15.0

## Haptic feedback duration (ms) on cell tap.
const TAP_VIBRATION_MS: int = 100

## How much larger the tap-collision shape is than the visible fill shape,
## expressed as a uniform scale from the fill polygon's centroid. Keeps the
## touch target slightly bigger than what's drawn without hand-authoring a
## second polygon per cell shape.
const COLLISION_SCALE: float = 1.1

@onready var _cell_text: Label = $Area2D/Node2D/Content/Label
@onready var _cell_icon: TextureRect = $Area2D/Node2D/Content/TextureRect
@onready var _cell_fsm: StateMachine = $StateMachine
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

## Mine-neighbor count for this cell.[br]
## [code]-1[/code] means this cell is a mine.[br]
## Positive values represent how many adjacent mines exist.[br]
## Use [method mark_as_mine] and [method increment_nearby] to modify — do not set directly.
var nearby: int = 0

## Grid coordinate of this cell (column, row).
var coord: Vector2i

## Screen position recorded on touch-down, used for tap detection.
var _touch_position: Vector2


func _ready() -> void:
	_cell_fsm.setup()
	_bind_collision_shape()


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
	_cell_fsm.defuse()


## Attempt to explore (reveal) this cell.
func explore() -> void:
	_cell_fsm.explore()


## Returns [code]true[/code] if this cell has already been explored.
func is_explored() -> bool:
	return _cell_fsm.state is ExploreState


## Returns [code]true[/code] if this cell is currently flagged.
func is_defused() -> bool:
	return _cell_fsm.state is DefuseState


## Updates the visual appearance of this cell. Called by FSM states to stay
## decoupled from the internal node tree.
func set_display(bg_color: Color, content_color: Color, icon: Texture2D = null, text: String = "") -> void:
	_cell_triangle.modulate = bg_color
	_cell_text.modulate = content_color
	_cell_icon.modulate = content_color
	_cell_icon.texture = icon
	_cell_text.text = text


## Overrides only the icon texture and its color. Used when the icon color
## differs from the default content color (e.g. mine icon on explosion).
func set_icon(icon: Texture2D, icon_color: Color) -> void:
	_cell_icon.texture = icon
	_cell_icon.modulate = icon_color


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, _local_shape: Object = null) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touch_position = event.position
	if event is InputEventScreenTouch and not event.pressed:
		if _touch_position.distance_to(event.position) < TAP_THRESHOLD:
			Input.vibrate_handheld(TAP_VIBRATION_MS)
			cell_pressed.emit(self, nearby)
