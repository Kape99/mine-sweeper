class_name UnkownState
extends BaseState


func defuse() -> void:
	state_machine.transition_to("Defused")


func explore() -> void:
	state_machine.transition_to("Explored")


func enter() -> void:
	setup_colors(GlobaState.secondary_color, GlobaState.main_color)


func exit() -> void:
	pass
