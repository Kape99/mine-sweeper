## Flagged cell state — the player has marked this cell as a suspected mine.
## Defusing again returns to [UnknownState]. Exploring is blocked while flagged.
class_name DefuseState
extends BaseState

const FLAG_ICON: Texture2D = preload("res://Asset/Icons/flag.svg")


func defuse() -> void:
	state_machine.transition_to("Unknown")


func explore() -> void:
	pass


func enter() -> void:
	owner.set_display(GlobalState.secondary_color, GlobalState.main_color, FLAG_ICON)
	owner.cell_defused.emit(owner, true)


func exit() -> void:
	owner.set_display(GlobalState.secondary_color, GlobalState.main_color)
	owner.cell_defused.emit(owner, false)
