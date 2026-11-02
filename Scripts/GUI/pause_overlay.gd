## Pause overlay shown on top of gameplay.
## All buttons are wired here; the actual scene transitions are delegated
## to ScreenManager and base.gd so this overlay stays decoupled.
class_name PauseOverlay
extends Control

const RESUME_TEXT: String = "Resume"
const RESTART_TEXT: String = "Restart"
const SETTINGS_TEXT: String = "Settings"
const QUIT_TEXT: String = "Quit to Menu"

const BUTTON_MIN_HEIGHT: int = 52
const BUTTON_SPACING: int = 12


func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	# Assigning `anchors_preset` does nothing on a control made in code;
	# this is the call that actually anchors (and sizes) it.
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# A full-screen CenterContainer keeps the buttons centered at any size.
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", BUTTON_SPACING)
	center.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_make_button(RESUME_TEXT, _on_resume))
	vbox.add_child(_make_button(RESTART_TEXT, _on_restart))
	vbox.add_child(_make_button(SETTINGS_TEXT, _on_settings))
	vbox.add_child(_make_button(QUIT_TEXT, _on_quit))


func _make_button(text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, BUTTON_MIN_HEIGHT)
	b.pressed.connect(callback)
	return b


func _get_screen_manager() -> ScreenManager:
	return get_tree().root.find_child("ScreenManager", true, false)


func _get_base() -> Node:
	return get_tree().root.find_child("Base", true, false)


## Resume/Restart/Quit go through base.gd, which owns the board node that
## must be un-dimmed (Base itself is a plain Node, not the gameplay Control).
func _on_resume() -> void:
	_get_base().resume_game()


func _on_restart() -> void:
	_get_base().restart_game()


func _on_settings() -> void:
	_get_screen_manager().push(load("res://Scenes/Menu/SettingsMenu.tscn").instantiate(), true, false)


func _on_quit() -> void:
	_get_base().return_to_menu()
