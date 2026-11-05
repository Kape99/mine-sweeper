class_name MainMenu
extends Control

signal start_requested
signal settings_requested
signal quit_requested
signal wrap_mode_changed(wrap: bool)

const BOARD_TYPE_NAMES: PackedStringArray = ["Triangle", "Square", "Hexagon"]
const BOARD_MODE_NAMES: PackedStringArray = ["Classic", "Wrap"]

@onready var _board_type_label: Label = $CenterContainer/Panel/BoardTypeRow/BoardTypeLabel
@onready var _board_type_prev: Button = $CenterContainer/Panel/BoardTypeRow/BoardTypePrev
@onready var _board_type_next: Button = $CenterContainer/Panel/BoardTypeRow/BoardTypeNext
@onready var _difficulty_label: Label = $CenterContainer/Panel/DifficultyRow/DifficultyLabel
@onready var _difficulty_prev: Button = $CenterContainer/Panel/DifficultyRow/DifficultyPrev
@onready var _difficulty_next: Button = $CenterContainer/Panel/DifficultyRow/DifficultyNext
@onready var _wrap_prev: Button = $CenterContainer/Panel/WrapRow/WrapPrev
@onready var _wrap_next: Button = $CenterContainer/Panel/WrapRow/WrapNext
@onready var _wrap_label: Label = $CenterContainer/Panel/WrapRow/WrapLabel
@onready var _seed_edit: LineEdit = $CenterContainer/Panel/SeedRow/SeedEdit
@onready var _start_button: Button = $CenterContainer/Panel/StartButton
@onready var _settings_button: Button = $CenterContainer/Panel/SettingsButton
@onready var _quit_button: Button = $CenterContainer/Panel/QuitButton


func _ready() -> void:
	_sync_from_global_state()
	_connect_signals()


func _process(_delta: float) -> void:
	# The debug settings (Settings screen) edit the raw board values while
	# this menu sits hidden in place; its process mode is restored before
	# it shows again, so this re-syncs the difficulty label on return.
	var difficulty: String = GlobalState.get_difficulty()
	if _difficulty_label.text != difficulty:
		_difficulty_label.text = difficulty


func _connect_signals() -> void:
	_board_type_prev.pressed.connect(_on_board_type_prev)
	_board_type_next.pressed.connect(_on_board_type_next)
	_difficulty_prev.pressed.connect(_on_difficulty_prev)
	_difficulty_next.pressed.connect(_on_difficulty_next)
	_wrap_prev.pressed.connect(_on_wrap_prev)
	_wrap_next.pressed.connect(_on_wrap_next)
	_seed_edit.text_changed.connect(_on_seed_changed)
	_start_button.pressed.connect(_on_start)
	_settings_button.pressed.connect(_on_settings)
	_quit_button.pressed.connect(_on_quit)
func _sync_from_global_state() -> void:
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]
	_difficulty_label.text = GlobalState.get_difficulty()
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	_seed_edit.text = GlobalState.board_seed


func _on_board_type_prev() -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board - 1, BOARD_TYPE_NAMES.size())
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]


func _on_board_type_next() -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board + 1, BOARD_TYPE_NAMES.size())
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]


## Cycles through the difficulty presets (raw values live in the debug
## settings; a "Custom" difficulty jumps back to the nearest preset).
func _cycle_difficulty(step: int) -> void:
	var idx: int = GlobalState.DIFFICULTY_NAMES.find(GlobalState.get_difficulty())
	idx = posmod((0 if idx == -1 else idx) + step, GlobalState.DIFFICULTY_NAMES.size())
	GlobalState.apply_difficulty(GlobalState.DIFFICULTY_NAMES[idx])
	_difficulty_label.text = GlobalState.DIFFICULTY_NAMES[idx]


func _on_difficulty_prev() -> void:
	_cycle_difficulty(-1)


func _on_difficulty_next() -> void:
	_cycle_difficulty(1)


func _on_wrap_prev() -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	wrap_mode_changed.emit(GlobalState.board_wrap)


func _on_wrap_next() -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	wrap_mode_changed.emit(GlobalState.board_wrap)


func _on_seed_changed(text: String) -> void:
	# Store normalized so "zuru7" and "ZURU7 " share the same board.
	GlobalState.board_seed = text.strip_edges().to_upper()


func _on_start() -> void:
	start_requested.emit()


func _on_settings() -> void:
	settings_requested.emit()


func _on_quit() -> void:
	quit_requested.emit()
