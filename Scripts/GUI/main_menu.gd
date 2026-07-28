class_name MainMenu
extends Control

signal start_requested
signal settings_requested
signal quit_requested
signal no_border_toggled(enabled: bool)
signal wrap_mode_changed(wrap: bool)

const BOARD_TYPE_NAMES: PackedStringArray = ["Triangle", "Square", "Hexagon"]
const BOARD_MODE_NAMES: PackedStringArray = ["Classic", "Wrap"]

@onready var _board_type_label: Label = $CenterContainer/Panel/BoardTypeRow/BoardTypeLabel
@onready var _board_type_prev: Button = $CenterContainer/Panel/BoardTypeRow/BoardTypePrev
@onready var _board_type_next: Button = $CenterContainer/Panel/BoardTypeRow/BoardTypeNext
@onready var _rows_spin: SpinBox = $CenterContainer/Panel/RowsRow/RowsSpin
@onready var _cols_spin: SpinBox = $CenterContainer/Panel/ColsRow/ColsSpin
@onready var _bomb_spin: SpinBox = $CenterContainer/Panel/BombRow/BombSpin
@onready var _seed_spin: SpinBox = $CenterContainer/Panel/SeedRow/SeedSpin
@onready var _wrap_prev: Button = $CenterContainer/Panel/WrapRow/WrapPrev
@onready var _wrap_next: Button = $CenterContainer/Panel/WrapRow/WrapNext
@onready var _wrap_label: Label = $CenterContainer/Panel/WrapRow/WrapLabel
@onready var _start_button: Button = $CenterContainer/Panel/StartButton
@onready var _settings_button: Button = $CenterContainer/Panel/SettingsButton
@onready var _quit_button: Button = $CenterContainer/Panel/QuitButton


func _ready() -> void:
	_sync_from_global_state()
	_connect_signals()


func _connect_signals() -> void:
	_board_type_prev.pressed.connect(_on_board_type_prev)
	_board_type_next.pressed.connect(_on_board_type_next)
	_rows_spin.value_changed.connect(_on_rows_changed)
	_cols_spin.value_changed.connect(_on_cols_changed)
	_bomb_spin.value_changed.connect(_on_bomb_changed)
	_seed_spin.value_changed.connect(_on_seed_changed)
	_wrap_prev.pressed.connect(_on_wrap_prev)
	_wrap_next.pressed.connect(_on_wrap_next)
	_start_button.pressed.connect(_on_start)
	_settings_button.pressed.connect(_on_settings)
	_quit_button.pressed.connect(_on_quit)


func _sync_from_global_state() -> void:
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]
	_rows_spin.value = GlobalState.board_rows
	_cols_spin.value = GlobalState.board_cols
	_bomb_spin.value = GlobalState.bomb_percentage * 100.0
	_seed_spin.value = GlobalState.board_seed
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]


func _on_board_type_prev() -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board - 1, BOARD_TYPE_NAMES.size())
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]


func _on_board_type_next() -> void:
	GlobalState.selected_board = posmod(GlobalState.selected_board + 1, BOARD_TYPE_NAMES.size())
	_board_type_label.text = BOARD_TYPE_NAMES[GlobalState.selected_board]


func _on_rows_changed(value: float) -> void:
	GlobalState.board_rows = int(value)


func _on_cols_changed(value: float) -> void:
	GlobalState.board_cols = int(value)


func _on_bomb_changed(value: float) -> void:
	GlobalState.bomb_percentage = value / 100.0


func _on_seed_changed(value: float) -> void:
	GlobalState.board_seed = int(value)


func _on_no_border_toggled(enabled: bool) -> void:
	GlobalState.no_border = enabled
	no_border_toggled.emit(enabled)


func _on_wrap_prev() -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	wrap_mode_changed.emit(GlobalState.board_wrap)


func _on_wrap_next() -> void:
	GlobalState.board_wrap = not GlobalState.board_wrap
	_wrap_label.text = BOARD_MODE_NAMES[1 if GlobalState.board_wrap else 0]
	wrap_mode_changed.emit(GlobalState.board_wrap)


func _on_start() -> void:
	start_requested.emit()


func _on_settings() -> void:
	settings_requested.emit()


func _on_quit() -> void:
	quit_requested.emit()
