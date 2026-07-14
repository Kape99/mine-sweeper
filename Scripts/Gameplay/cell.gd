## Base class for all cell types (square, triangle, hexagon).
## Manages cell state through [StateMachine], handles touch input, and emits
## gameplay signals consumed by the board.
class_name CellBase
extends Container

## Maximum distance (in pixels) between touch-down and touch-up to register a tap.
const TAP_THRESHOLD: float = 15.0

## Haptic feedback duration (ms) on cell tap.
const TAP_VIBRATION_MS: int = 100

@onready var _cell_text: Label = $Area2D/Node2D/Content/Label
@onready var _cell_icon: TextureRect = $Area2D/Node2D/Content/TextureRect
@onready var _cell_fsm: StateMachine = $StateMachine
@onready var _cell_triangle: Polygon2D = $Area2D/Polygon2D

## Emitted when the player taps this cell. [param cell] is self, [param nearby]
## is the mine-neighbor count (or -1 if mine).
signal cell_pressed(cell: CellBase, nearby: int)

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
## The setter accumulates: assigning [code]1[/code] increments the count by 1.
## Assigning [code]-1[/code] permanently marks the cell as a mine.
var nearby: int = 0:
	set(value):
		if nearby == -1 or value == -1:
			nearby = -1
		else:
			nearby += value

## Grid coordinate of this cell (column, row).
var coord: Vector2i

## Screen position recorded on touch-down, used for tap detection.
var _touch_position: Vector2


func _ready() -> void:
	_cell_fsm.setup()


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


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touch_position = event.position
	if event is InputEventScreenTouch and not event.pressed:
		if _touch_position.distance_to(event.position) < TAP_THRESHOLD:
			Input.vibrate_handheld(TAP_VIBRATION_MS)
			cell_pressed.emit(self, nearby)
