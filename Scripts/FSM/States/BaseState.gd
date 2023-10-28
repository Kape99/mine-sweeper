class_name BaseState
extends Node

var state_machine: StateMachine = null


func defuse() -> void:
	pass


func explore() -> void:
	pass


func enter() -> void:
	pass


func exit() -> void:
	pass


func setup_colors(background_color: Color, content_color: Color):
	owner._cell_text.modulate = content_color
	owner._cell_icon.modulate = content_color

	owner._cell_triangle.modulate = background_color
