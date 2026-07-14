class_name DefuseState
extends BaseState


func defuse() -> void:
	state_machine.transition_to("Unknown")


func explore() -> void:
	pass


func enter() -> void:
	setup_colors(GlobalState.secondary_color, GlobalState.main_color)
	owner._cell_icon.texture = preload("res://Asset/Icons/flag.svg")
	owner.cell_defused.emit(owner, true)


func exit() -> void:
	owner._cell_icon.texture = null
	owner.cell_defused.emit(owner, false)
