class_name UnkownState
extends BaseState


func defuse() -> void:
	state_machine.transition_to("Defused")


func explore() -> void:
	state_machine.transition_to("Explored")


func enter() -> void:
	setup_colors(GlobaState.accent_color, GlobaState.base_color)


func exit() -> void:
	pass
