class_name ExploreState
extends BaseState


func defuse() -> void:
	pass


func explore() -> void:
	pass


func enter() -> void:
	setup_colors(GlobaState.base_color, GlobaState.accent_color)
	if owner.nearby == -1:
		Input.vibrate_handheld(500)

		owner._cell_icon.texture = preload("res://Asset/Icons/mine.svg")
		owner._cell_icon.modulate = Color.INDIAN_RED
	else:
		if owner.nearby != 0:
			owner._cell_text.text = str(owner.nearby)


func exit() -> void:
	pass
