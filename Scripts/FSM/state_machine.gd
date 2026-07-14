## Generic finite state machine for [CellBase] nodes.
## Manages state transitions and delegates [method defuse] / [method explore]
## calls to the active [BaseState].
class_name StateMachine
extends Node

## Emitted after transitioning to a new state.
signal transitioned(state_name: String)

## Possible cell states (used for external queries, not for FSM logic).
enum CellState {
	UNKNOWN,
	EXPLORED,
	DEFUSED,
}

## Path to the initial active state node. Set in the inspector.
@export var initial_state := NodePath()

## The currently active state.
@onready var state: BaseState = get_node(initial_state)


## Initializes all child states and enters the initial state.
## Must be called after the owner is ready (awaits owner).
func setup() -> void:
	await owner
	for child: BaseState in get_children():
		child.state_machine = self
	state.enter()


## Delegates a defuse action to the current state.
func defuse() -> void:
	state.defuse()


## Delegates an explore action to the current state.
func explore() -> void:
	state.explore()


## Exits the current state, transitions to [param target_state_name], and enters it.
## Silently returns if the target state node does not exist (allows reusable states
## across different FSM configurations).
func transition_to(target_state_name: String) -> void:
	if not has_node(target_state_name):
		return
	state.exit()
	state = get_node(target_state_name)
	state.enter()
	transitioned.emit(state.name)
