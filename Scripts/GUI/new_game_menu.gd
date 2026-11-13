## New game sheet: board shape, difficulty, mode and seed, opened from the
## summary line under PLAY on the main menu. Changes are saved to
## [GlobalState] as they're made, so PLAY on the main menu reuses them.
class_name NewGameMenu
extends Control

## Emitted by this sheet's PLAY button: start a game with these settings.
signal play_requested

const PANEL_WIDTH: int = 340
const ROW_SPACING: int = 12
const CONTROL_MIN_HEIGHT: int = 44
const LABEL_WIDTH: int = 90
const BACK_BUTTON_TEXT: String = "← Back"

var _board_label: Label
var _difficulty_label: Label
var _mode_label: Label
var _seed_edit: LineEdit


func _ready() -> void:
	_build_ui()
	_sync_from_global_state()


func _process(_delta: float) -> void:
	# Difficulty can read "Custom" after the debug settings change raw values.
	var difficulty: String = GlobalState.get_difficulty()
	if _difficulty_label.text != difficulty:
		_difficulty_label.text = difficulty


func _sync_from_global_state() -> void:
	_board_label.text = MainMenu.BOARD_TYPE_NAMES[GlobalState.selected_board]
	_difficulty_label.text = GlobalState.get_difficulty()
	_mode_label.text = MainMenu.BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	_seed_edit.text = GlobalState.board_seed


func _cycle_board(step: int) -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board + step, MainMenu.BOARD_TYPE_NAMES.size())
	_board_label.text = MainMenu.BOARD_TYPE_NAMES[GlobalState.selected_board]


## Cycles through the difficulty presets (raw values live in the debug
## settings; a "Custom" difficulty jumps back to the nearest preset).
func _cycle_difficulty(step: int) -> void:
	var idx: int = GlobalState.DIFFICULTY_NAMES.find(GlobalState.get_difficulty())
	idx = posmod((0 if idx == -1 else idx) + step, GlobalState.DIFFICULTY_NAMES.size())
	GlobalState.apply_difficulty(GlobalState.DIFFICULTY_NAMES[idx])
	_difficulty_label.text = GlobalState.DIFFICULTY_NAMES[idx]


func _toggle_mode(_step: int) -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_mode_label.text = MainMenu.BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]


func _on_seed_changed(text: String) -> void:
	# Store normalized so "test7" and "TEST7 " share the same board.
	GlobalState.board_seed = text.strip_edges().to_upper()


func _on_back_pressed() -> void:
	var sm: ScreenManager = get_tree().root.find_child("ScreenManager", true, false)
	if sm:
		sm.pop()


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = &"CardPanel"
	center.add_child(card)

	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_constant_override("separation", ROW_SPACING)
	card.add_child(panel)

	var title: Label = Label.new()
	title.text = "NEW GAME"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	_board_label = _add_cycle_row(panel, "Board", _cycle_board)
	_difficulty_label = _add_cycle_row(panel, "Difficulty", _cycle_difficulty)
	_mode_label = _add_cycle_row(panel, "Mode", _toggle_mode)

	var seed_row: HBoxContainer = _add_row(panel, "Seed")
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.max_length = 8
	_seed_edit.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.text_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_edit)
	WebTextInput.attach(_seed_edit, "Seed (empty = random board)")

	var seed_hint: Label = Label.new()
	seed_hint.text = "Share a seed (e.g. FABIO) to play the same board as a friend."
	seed_hint.theme_type_variation = &"MutedLabel"
	seed_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seed_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(seed_hint)

	var play: Button = Button.new()
	play.name = "PlayButton"
	play.text = "PLAY"
	play.theme_type_variation = &"PrimaryButton"
	play.custom_minimum_size = Vector2(0, 48)
	play.pressed.connect(play_requested.emit)
	panel.add_child(play)

	var back: Button = Button.new()
	back.name = "BackButton"
	back.text = BACK_BUTTON_TEXT
	back.theme_type_variation = &"GhostButton"
	back.custom_minimum_size = Vector2(0, CONTROL_MIN_HEIGHT)
	back.pressed.connect(_on_back_pressed)
	panel.add_child(back)


func _add_row(parent: Control, label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	parent.add_child(row)
	return row


## A "Label  ◀ value ▶" row; [param on_step] gets -1 or +1. Returns the
## value label.
func _add_cycle_row(parent: Control, label_text: String, on_step: Callable) -> Label:
	var row: HBoxContainer = _add_row(parent, label_text)
	var prev: Button = Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(CONTROL_MIN_HEIGHT, CONTROL_MIN_HEIGHT)
	prev.pressed.connect(on_step.bind(-1))
	row.add_child(prev)
	var value: Label = Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	var next: Button = Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(CONTROL_MIN_HEIGHT, CONTROL_MIN_HEIGHT)
	next.pressed.connect(on_step.bind(1))
	row.add_child(next)
	return value
