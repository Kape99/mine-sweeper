## Revealed cell state — the cell content is visible.
## If the cell is a mine, emits [signal CellBase.cell_exploded].
## Otherwise, emits [signal CellBase.cell_explored] and shows the neighbor count.
class_name ExploreState
extends BaseState

const MINE_ICON: Texture2D = preload("res://Asset/Icons/mine.svg")


func defuse() -> void:
	pass


func explore() -> void:
	pass


func enter() -> void:
	if owner.is_mine():
		owner.set_display(GlobalState.main_color, GlobalState.secondary_color)
		owner.set_icon(MINE_ICON, GlobalState.background_color)
		owner.cell_exploded.emit(owner)
	else:
		var text: String = str(owner.nearby) if owner.nearby != 0 else ""
		owner.set_display(GlobalState.main_color, GlobalState.secondary_color, null, text)
		owner.cell_explored.emit(owner)


func exit() -> void:
	pass
