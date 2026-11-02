## Settings menu screen.
## Built programmatically so the UI stays in sync with Settings.gd without
## hand-authoring a complex .tscn. Each control is wired to the matching
## Settings property via its setter, which persists automatically.
class_name SettingsMenu
extends Control

## Padding (px) inside the settings panel on each side.
const PANEL_PADDING: int = 24

## Width (px) of the settings panel; its height follows the content.
const PANEL_WIDTH: int = 360

## Vertical spacing between setting rows.
const ROW_SPACING: int = 16

## Minimum touch-friendly height for interactive controls.
const CONTROL_MIN_HEIGHT: int = 48

const BACK_BUTTON_TEXT: String = "← Back"

var _panel: Control


func _ready() -> void:
	_build_ui()
	# Refresh all controls to reflect current stored values
	_refresh_all()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	# Assigning `anchors_preset` does nothing on a control made in code;
	# this is the call that actually anchors (and sizes) it.
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# A full-screen CenterContainer centers the panel at its content size.
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = VBoxContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.add_theme_constant_override("separation", ROW_SPACING)
	center.add_child(_panel)

	# Title
	var title: Label = _make_label("SETTINGS", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	_panel.add_child(HSeparator.new())

	# --- Audio ---
	_panel.add_child(_make_section_header("Audio"))

	_panel.add_child(_make_row("Master", _make_slider(Settings.master_volume, 0.0, 1.0, 0.05,
		func(v): Settings.master_volume = v)))

	_panel.add_child(_make_row("Music", _make_slider(Settings.music_volume, 0.0, 1.0, 0.05,
		func(v): Settings.music_volume = v)))

	_panel.add_child(_make_row("SFX", _make_slider(Settings.sfx_volume, 0.0, 1.0, 0.05,
		func(v): Settings.sfx_volume = v)))

	# --- Haptics ---
	_panel.add_child(_make_section_header("Haptics"))

	var vib_row: HBoxContainer = _make_row("Vibration", _make_checkbox(Settings.vibration_enabled,
		func(v): Settings.vibration_enabled = v))
	_panel.add_child(vib_row)

	# --- Graphics ---
	_panel.add_child(_make_section_header("Graphics"))

	var quality_row: HBoxContainer = _make_row("Quality", _make_option_button(
		["Low", "Medium", "High"],
		_settings_index_for_quality(),
		func(idx): Settings.graphics_quality = _quality_for_index(idx)
	))
	_panel.add_child(quality_row)

	var fs_row: HBoxContainer = _make_row("Fullscreen", _make_checkbox(Settings.fullscreen,
		func(v): Settings.fullscreen = v))
	_panel.add_child(fs_row)

	_panel.add_child(_make_row("Wrap Board", _make_checkbox(Settings.board_wrap,
		func(v): Settings.board_wrap = v)))

	# --- Spacer ---
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_panel.add_child(spacer)

	# --- Back button ---
	var back: Button = Button.new()
	back.text = BACK_BUTTON_TEXT
	back.custom_minimum_size = Vector2(200, CONTROL_MIN_HEIGHT)
	back.pressed.connect(_on_back_pressed)
	_panel.add_child(back)


func _on_back_pressed() -> void:
	var sm: ScreenManager = get_tree().root.find_child("ScreenManager", true, false)
	if sm:
		sm.pop()


## Rebuild all controls from current Settings values (used on pop/push so
## sliders reflect any changes made while the menu was hidden).
func _refresh_all() -> void:
	for child: Node in _panel.get_children():
		_refresh_row(child)


func _refresh_row(node: Node) -> void:
	if node is HBoxContainer:
		for c in node.get_children():
			if c is HSlider:
				c.value = _slider_value_for_row(node)
			elif c is CheckBox:
				c.button_pressed = _checkbox_value_for_row(node)
			elif c is OptionButton:
				_option_select_for_row(node)


func _slider_value_for_row(row: HBoxContainer) -> float:
	var label: String = (row.get_child(0) as Label).text.strip_edges().to_lower()
	match label:
		"master": return Settings.master_volume
		"music":  return Settings.music_volume
		"sfx":    return Settings.sfx_volume
	return 0.5


func _checkbox_value_for_row(row: HBoxContainer) -> bool:
	var label: String = (row.get_child(0) as Label).text.strip_edges().to_lower()
	match label:
		"vibration": return Settings.vibration_enabled
		"fullscreen": return Settings.fullscreen
		"wrap board": return Settings.board_wrap
	return false


func _option_select_for_row(row: HBoxContainer) -> void:
	var ob: OptionButton = row.get_child(1) as OptionButton
	if not ob:
		return
	var label: String = (row.get_child(0) as Label).text.strip_edges().to_lower()
	match label:
		"quality":
			ob.select(_settings_index_for_quality())


func _settings_index_for_quality() -> int:
	match Settings.graphics_quality:
		"low":    return 0
		"high":   return 2
		_:       return 1  # medium


func _quality_for_index(idx: int) -> String:
	match idx:
		0: return "low"
		2: return "high"
		_: return "medium"


# ── UI builder helpers ──────────────────────────────────────────────────

func _make_label(text: String, font_size: int = 18) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _make_section_header(text: String) -> Label:
	var l: Label = _make_label(text.to_upper(), 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	return l


func _make_row(label_text: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100, CONTROL_MIN_HEIGHT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	control.custom_minimum_size = Vector2(200, CONTROL_MIN_HEIGHT)
	row.add_child(control)
	return row


func _make_slider(value: float, min_val: float, max_val: float, step: float,
		on_changed: Callable) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = min_val
	s.max_value = max_val
	s.step = step
	s.value = value
	s.tick_count = int((max_val - min_val) / step) + 1
	s.ticks_on_borders = true
	s.value_changed.connect(on_changed)
	return s


func _make_checkbox(checked: bool, on_toggled: Callable) -> CheckBox:
	var cb: CheckBox = CheckBox.new()
	cb.button_pressed = checked
	cb.toggled.connect(on_toggled)
	return cb


func _make_option_button(items: PackedStringArray, selected: int,
		on_selected: Callable) -> OptionButton:
	var ob: OptionButton = OptionButton.new()
	for item: String in items:
		ob.add_item(item.capitalize())
	ob.select(selected)
	ob.item_selected.connect(on_selected)
	return ob
