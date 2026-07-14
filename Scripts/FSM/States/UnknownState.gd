class_name UnknownState
extends BaseState


func defuse() -> void:
	state_machine.transition_to("Defused")


func explore() -> void:
	state_machine.transition_to("Explored")


func enter() -> void:
	setup_colors(GlobalState.secondary_color, GlobalState.main_color)


func exit() -> void:
	pass
