## Abstract base class for cell FSM states.
## Subclasses override [method defuse], [method explore], [method enter],
## and [method exit] to implement state-specific behavior.
class_name BaseState
extends Node

## Reference to the owning [StateMachine]. Set during [method StateMachine.setup].
var state_machine: StateMachine = null


## Called when the player attempts to defuse while in this state.
func defuse() -> void:
	pass


## Called when the player attempts to explore while in this state.
func explore() -> void:
	pass


## Called when entering this state. Override to apply visuals and emit signals.
func enter() -> void:
	pass


## Called when leaving this state. Override to clean up visuals and emit signals.
func exit() -> void:
	pass


## Applies [param background_color] to the cell polygon and [param content_color]
## to the label and icon.
func setup_colors(background_color: Color, content_color: Color) -> void:
	owner._cell_text.modulate = content_color
	owner._cell_icon.modulate = content_color
	owner._cell_triangle.modulate = background_color
