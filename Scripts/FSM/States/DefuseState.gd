class_name DefuseState
extends BaseState


func defuse() -> void:
	state_machine.transition_to("Unknown")


func explore() -> void:
	pass


func enter() -> void:
	setup_colors(GlobaState.accent_color, GlobaState.base_color)
	owner._cell_icon.texture = preload("res://Asset/Icons/flag.svg")
	owner.emit_signal("cell_defused", owner, true)


func exit() -> void:
	owner._cell_icon.texture = null
	owner.emit_signal("cell_defused", owner, false)
