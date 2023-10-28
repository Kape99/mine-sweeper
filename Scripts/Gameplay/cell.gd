class_name CellBase extends Container

@onready var _cell_text: Label = $Area2D/Node2D/Content/Label
@onready var _cell_icon: TextureRect = $Area2D/Node2D/Content/TextureRect
@onready var _cell_fsm: StateMachine = $StateMachine
@onready var _cell_triangle: Polygon2D = $Area2D/Polygon2D

signal cell_explored(cell: CellBase, sould_propagate: bool)
signal cell_defused(cell: CellBase, is_defused: bool)
signal cell_exploded(cell: CellBase)

# If it is set to -1 it means it is a MINE
# Otherwhise it represent the number of MINES nearby
var nearby: int = 0:
	set(value):
		if nearby == -1 or value == -1:
			nearby = -1
		else:
			nearby += 1

var coord: Vector2i

var touch_position: Vector2


func _ready():
	_cell_fsm.setup()


func explore():
	_cell_fsm.explore()


func _handle_press():
	if GlobaState._defusing:
		_cell_fsm.defuse()
	else:
		_cell_fsm.explore()


func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event as InputEventScreenTouch and event.pressed:
		touch_position = event.position
	if event as InputEventScreenTouch and not event.pressed and touch_position.distance_to(event.position) < 5:
		_handle_press()
