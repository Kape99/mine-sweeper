## Abstract base class for cell FSM states.
## Subclasses override [method defuse], [method explore], [method enter],
## and [method exit] to implement state-specific behavior.
## States communicate visuals through [method CellBase.set_display] to stay decoupled
## from the cell's internal node tree.
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
