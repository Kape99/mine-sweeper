## Revealed cell state — the cell content is visible.
## If the cell is a mine, emits [signal CellBase.cell_exploded].
## Otherwise, emits [signal CellBase.cell_explored] and shows the neighbor count.
class_name ExploreState
extends BaseState


func defuse() -> void:
	pass


func explore() -> void:
	pass


func enter() -> void:
	setup_colors(GlobalState.main_color, GlobalState.secondary_color)
	if owner.nearby == -1:
		owner._cell_icon.texture = preload("res://Asset/Icons/mine.svg")
		owner._cell_icon.modulate = GlobalState.background_color
		owner.cell_exploded.emit(owner)
	else:
		owner.cell_explored.emit(owner)
		if owner.nearby != 0:
			owner._cell_text.text = str(owner.nearby)


func exit() -> void:
	pass
