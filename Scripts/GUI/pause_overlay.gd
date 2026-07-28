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
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.anchors_preset = Control.PRESET_CENTER
	center.custom_minimum_size = Vector2(280, 0)
	add_child(center)

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


## Called by ScreenManager after the fade-out completes.
func _on_resume() -> void:
	get_tree().root.get_node("GUI/ScreenManager").hide_pause(get_tree().root.get_node("Base"))


func _on_restart() -> void:
	var base: Node = get_tree().root.get_node("Base")
	get_tree().root.get_node("GUI/ScreenManager").hide_pause(base)
	base._reset()
	base._load_game()


func _on_settings() -> void:
	var sm: ScreenManager = get_tree().root.get_node("GUI/ScreenManager")
	sm.push(load("res://Scenes/Menu/SettingsMenu.tscn").instantiate(), true, false)


func _on_quit() -> void:
	var base: Node = get_tree().root.get_node("Base")
	get_tree().root.get_node("GUI/ScreenManager").hide_pause(base)
	base._reset()
