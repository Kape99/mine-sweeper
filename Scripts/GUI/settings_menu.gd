## Settings menu screen.
## Currently a placeholder: no settings remain. Kept so PauseOverlay can
## still push it.
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

	# --- Timers ---
	_panel.add_child(_make_section_header("Timers"))

	_panel.add_child(_make_row("Tap threshold", _make_slider(Settings.tap_threshold, 1.0, 100.0, 1.0,
		func(v): Settings.tap_threshold = v)))

	_panel.add_child(_make_row("Long press ms", _make_slider(float(Settings.long_press_threshold_ms), 50.0, 5000.0, 50.0,
		func(v): Settings.long_press_threshold_ms = int(v))))

	var dt_row: HBoxContainer = _make_row("Double tap", _make_checkbox(Settings.use_double_tap,
		func(v): Settings.use_double_tap = v))
	_panel.add_child(dt_row)

	_panel.add_child(_make_row("Double tap ms", _make_slider(float(Settings.double_tap_window_ms), 150.0, 2000.0, 50.0,
		func(v): Settings.double_tap_window_ms = int(v))))

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


func _make_checkbox(checked: bool, on_toggled: Callable) -> CheckBox:
	var cb: CheckBox = CheckBox.new()
	cb.button_pressed = checked
	cb.toggled.connect(on_toggled)
	return cb


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
