class_name CellBase extends Container

@onready var _cell_text: Label = $Area2D/Node2D/Content/Label
@onready var _cell_icon: TextureRect = $Area2D/Node2D/Content/TextureRect
@onready var _cell_fsm: StateMachine = $StateMachine
@onready var _cell_triangle: Polygon2D = $Area2D/Polygon2D

signal cell_pressed(cell: CellBase, nearby: int)

signal cell_explored(cell: CellBase)
signal cell_defused(cell: CellBase, is_defused: bool)
signal cell_exploded(cell: CellBase)

# If it is set to -1 it means it is a MINE
# Otherwise it represents the number of MINES nearby
var nearby: int = 0:
	set(value):
		if nearby == -1 or value == -1:
			nearby = -1
		else:
			nearby += value

var coord: Vector2i

var touch_position: Vector2


func _ready():
	_cell_fsm.setup()


func defuse():
	_cell_fsm.defuse()


func explore():
	_cell_fsm.explore()


func is_explored() -> bool:
	return _cell_fsm.state is ExploreState


func is_defused() -> bool:
	return _cell_fsm.state is DefuseState


func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event as InputEventScreenTouch and event.pressed:
		touch_position = event.position
	if event as InputEventScreenTouch and not event.pressed and touch_position.distance_to(event.position) < 15:
		Input.vibrate_handheld(100)
		cell_pressed.emit(self, nearby)



