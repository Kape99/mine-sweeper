class_name ExploreState
extends BaseState


func defuse() -> void:
	pass


func explore() -> void:
	pass


func enter() -> void:
	setup_colors(GlobaState.main_color, GlobaState.secondary_color)
	if owner.nearby == -1:
		owner._cell_icon.texture = preload("res://Asset/Icons/mine.svg")
		owner._cell_icon.modulate = GlobaState.background_color

		owner.emit_signal("cell_exploded", owner)

	else:
		owner.emit_signal("cell_explored", owner)
		if owner.nearby != 0:
			owner._cell_text.text = str(owner.nearby)


func exit() -> void:
	pass
