class_name CellBase extends Container

@onready var _cell_text: Label = $Area2D/Node2D/Content/Label
@onready var _cell_icon: TextureRect = $Area2D/Node2D/Content/TextureRect
@onready var _cell_fsm: StateMachine = $StateMachine
@onready var _cell_triangle: Polygon2D = $Area2D/Polygon2D

signal cell_pressed(cell: CellBase, nearby: int)

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

var pressed = false


func _ready():
	_cell_fsm.setup()


func defuse():
	_cell_fsm.defuse()


func explore():
	Input.vibrate_handheld(100)
	_cell_fsm.explore()


func explore_delayed(delay: float):
	$Timer.wait_time = delay
	$Timer.start()


func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event as InputEventScreenTouch and event.pressed:
		touch_position = event.position
	if event as InputEventScreenTouch and not event.pressed and touch_position.distance_to(event.position) < 10:
		emit_signal("cell_pressed", self, nearby)


func _on_timer_timeout():
	_cell_fsm.explore()
