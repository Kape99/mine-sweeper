extends Control
## Debug tool for the Talo leaderboard used by the daily challenge.
##
## Runs the same calls as the end screen (identify, add_entry, get_entries)
## and logs everything the game throws away: whether identify failed,
## whether add_entry stored the submitted score or kept an older one, the
## leaderboard's sort mode, paging and archived entries.
##
## It talks to the REAL Talo backend from addons/talo/settings.cfg:
## "Submit" writes a real entry, so use a throwaway name (or a test
## leaderboard) when trying things out.
##
## Run it from the editor (Run Current Scene), or read-only from a shell:
##   godot --headless --path . res://Scenes/Tools/leaderboard_debug.tscn -- --refresh [--archived] [--leaderboard=daily]

const FinalScreen = preload("res://Scripts/GUI/final_screen.gd")

const TOP_LIMIT: int = 10

const COLOR_OK: Color = Color("2e7d32")
const COLOR_WARN: Color = Color("b26a00")
const COLOR_ERROR: Color = Color("c62828")
const COLOR_CMD: Color = Color("1565c0")

var _leaderboard_edit: LineEdit
var _name_edit: LineEdit
var _score_spin: SpinBox
var _archived_check: CheckBox
var _status_label: Label
var _page_label: Label
var _prev_button: Button
var _next_button: Button
var _output: RichTextLabel
var _buttons: Array[Button] = []

var _page: int = 0
var _is_last_page: bool = true
var _busy: bool = false
var _warned_sort_mode: bool = false


func _ready() -> void:
	_build_ui()
	Talo.players.identification_failed.connect(_on_identification_failed)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--leaderboard="):
			_leaderboard_edit.text = arg.get_slice("=", 1)
		elif arg == "--archived":
			_archived_check.button_pressed = true

	_log("Talo API: %s (offline mode setting: %s)" % [Talo.settings.api_url, Talo.settings.offline_mode])
	var online: bool = await Talo.health_check.ping()
	if online:
		_ok("Health check OK")
	else:
		_error("Health check failed: Talo is unreachable, every call below will fail or go offline")
	_update_status()

	if "--refresh" in args:
		await _refresh()
		get_tree().quit()


# --- Actions -----------------------------------------------------------------

func _identify() -> bool:
	var player_name: String = _name_edit.text
	_cmd("players.identify(\"%s\", \"%s\")" % [FinalScreen.TALO_SERVICE, player_name])
	if player_name.is_empty():
		_warn("Name is empty. The game sends an empty name as-is too.")
	if player_name.uri_encode() != player_name:
		_warn("Name needs URL encoding (\"%s\"), but Talo puts it in the URL unencoded: the server may receive a different name or reject the request." % player_name.uri_encode())

	var alias: TaloPlayerAlias = await Talo.players.identify(FinalScreen.TALO_SERVICE, player_name)
	_update_status()
	if alias == null:
		_error("identify returned null. Talo.current_alias is now %s: in the game, add_entry would %s." % [
			_alias_text(Talo.current_alias),
			"submit under that OLD alias" if Talo.has_identity() else "send nothing at all",
		])
		return false

	_ok("Identified as alias %s, player %s" % [_alias_text(alias), alias.player.id if alias.player else "?"])
	if alias.identifier != player_name:
		_warn("The server's identifier \"%s\" differs from the typed name \"%s\"" % [alias.identifier, player_name])
	return true


func _submit() -> void:
	var leaderboard: String = _leaderboard_name()
	var score: float = _score_spin.value
	_cmd("leaderboards.add_entry(\"%s\", %s) as %s" % [leaderboard, score, _alias_text(Talo.current_alias)])
	if not Talo.has_identity():
		_error("No identity: add_entry returns without sending anything (this is what the game does when identify fails)")
		return

	var res: LeaderboardsAPI.AddEntryResult = await Talo.leaderboards.add_entry(leaderboard, score)
	if not res.success:
		_error("add_entry failed (wrong leaderboard name, network error, or rejected request)")
		for prop: TaloRejectedProp in res.rejected_props:
			_error("  rejected prop %s: %s" % [prop.key, prop.message])
		return

	var entry: TaloLeaderboardEntry = res.entry
	_ok("Success: updated=%s, entry #%d, position %d, stored score %s" % [res.updated, entry.id, entry.position, entry.score])
	if not is_equal_approx(entry.score, score):
		_warn("Stored score is %s, not the submitted %s. The leaderboard keeps one entry per player (unique entries), and under %s sorting the new score isn't better, so Talo kept the old one." % [
			entry.score, score, _sort_mode_text(entry.leaderboard_sort_mode)])
	elif res.updated:
		_ok("Replaced this player's previous entry (unique entries)")
	else:
		_log("Created a new entry")
	_check_sort_mode(entry.leaderboard_sort_mode)


func _refresh(alias_only: bool = false) -> void:
	var leaderboard: String = _leaderboard_name()
	var options := LeaderboardsAPI.GetEntriesOptions.new()
	options.page = _page
	options.include_archived = _archived_check.button_pressed
	if alias_only:
		if not Talo.has_identity():
			_error("Identify first to list this player's entries")
			return
		options.alias_id = Talo.current_alias.id
	_cmd("leaderboards.get_entries(\"%s\", page=%d, archived=%s%s)" % [
		leaderboard, options.page, options.include_archived,
		", alias=%d" % options.alias_id if alias_only else ""])

	var page: LeaderboardsAPI.EntriesPage = await Talo.leaderboards.get_entries(leaderboard, options)
	if page == null:
		_error("get_entries failed (offline, wrong leaderboard name or bad access key). The game shows an empty list in this case.")
		return

	_log("%d entries in total, %d per page, last page: %s" % [page.count, page.items_per_page, page.is_last_page])
	_print_entries(page.entries)
	if not page.entries.is_empty():
		_check_sort_mode(page.entries[0].leaderboard_sort_mode)

	if alias_only:
		return
	_is_last_page = page.is_last_page
	_update_paging()
	if Talo.has_identity() and not page.entries.any(_is_current_alias):
		_warn("%s isn't on this page" % _alias_text(Talo.current_alias))
	if _page == 0 and not page.is_last_page:
		_warn("The game only loads this first page: entries on later pages never show in-game")


func _top_entries() -> void:
	var leaderboard: String = _leaderboard_name()
	_cmd("leaderboards.get_top_entries(\"%s\", %d)" % [leaderboard, TOP_LIMIT])
	if not Talo.has_identity():
		_error("get_top_entries needs an identity: identify first")
		return
	var res: LeaderboardsAPI.TopEntriesResult = await Talo.leaderboards.get_top_entries(leaderboard, TOP_LIMIT)
	if res == null:
		_error("get_top_entries failed")
		return
	_log("Top %d:" % TOP_LIMIT)
	_print_entries(res.top_entries)
	_log("Entries of %s:" % _alias_text(Talo.current_alias))
	_print_entries(res.player_entries)


# --- Button handlers (one request at a time, like the game) -------------------

func _on_identify_pressed() -> void:
	if _begin():
		await _identify()
		_end()


func _on_submit_pressed() -> void:
	if _begin():
		await _submit()
		_end()


func _on_identify_submit_pressed() -> void:
	# Same sequence as FinalScreen._submit_score, which doesn't stop when
	# identify fails.
	if _begin():
		await _identify()
		await _submit()
		_page = 0
		await _refresh()
		_end()


func _on_refresh_pressed() -> void:
	if _begin():
		await _refresh()
		_end()


func _on_page_pressed(delta: int) -> void:
	if _begin():
		_page = maxi(0, _page + delta)
		await _refresh()
		_end()


func _on_mine_pressed() -> void:
	if _begin():
		await _refresh(true)
		_end()


func _on_top_pressed() -> void:
	if _begin():
		await _top_entries()
		_end()


func _on_identification_failed(error: TaloIdentifyError) -> void:
	_error("identification_failed: %s" % TaloIdentifyError.ErrorCode.keys()[error.code])


func _begin() -> bool:
	if _busy:
		return false
	_busy = true
	for button: Button in _buttons:
		button.disabled = true
	return true


func _end() -> void:
	_busy = false
	for button: Button in _buttons:
		button.disabled = false
	_update_paging()
	_update_status()


# --- Helpers -------------------------------------------------------------------

func _leaderboard_name() -> String:
	var leaderboard: String = _leaderboard_edit.text.strip_edges()
	return leaderboard if not leaderboard.is_empty() else FinalScreen.TALO_LEADERBOARD


func _is_current_alias(entry: TaloLeaderboardEntry) -> bool:
	return Talo.has_identity() and entry.player_alias != null and entry.player_alias.id == Talo.current_alias.id


func _alias_text(alias: TaloPlayerAlias) -> String:
	return "none" if alias == null else "#%d \"%s\"" % [alias.id, alias.identifier]


func _sort_mode_text(mode: TaloLeaderboardEntry.LeaderboardSortMode) -> String:
	return "ASC" if mode == TaloLeaderboardEntry.LeaderboardSortMode.ASC else "DESC"


## The score is a time, so lower must rank higher.
func _check_sort_mode(mode: TaloLeaderboardEntry.LeaderboardSortMode) -> void:
	if mode == TaloLeaderboardEntry.LeaderboardSortMode.ASC:
		if not _warned_sort_mode:
			_ok("Sort mode is ASC (lower time ranks higher)")
			_warned_sort_mode = true
		return
	_warn("Sort mode is DESC: SLOWER times rank higher. The score is a time, so set it to ascending in the Talo dashboard.")


func _print_entries(entries: Array[TaloLeaderboardEntry]) -> void:
	if entries.is_empty():
		_log("  (no entries)")
		return
	for entry: TaloLeaderboardEntry in entries:
		var identifier: String = entry.player_alias.identifier if entry.player_alias else "Unknown"
		var line: String = "%s%4d  %-16s %8s  %s" % [
			"*" if _is_current_alias(entry) else " ",
			entry.position,
			identifier.left(16),
			str(entry.score),
			entry.updated_at.left(16).replace("T", " "),
		]
		if not entry.deleted_at.is_empty():
			line += "  [archived]"
		_log(line)


func _update_status() -> void:
	_status_label.text = "Current alias: %s" % _alias_text(Talo.current_alias)


func _update_paging() -> void:
	_page_label.text = "Page %d" % _page
	_prev_button.disabled = _busy or _page == 0
	_next_button.disabled = _busy or _is_last_page


func _log(text: String, color: Color = Color.TRANSPARENT) -> void:
	print(text)
	if color.a > 0.0:
		_output.push_color(color)
		_output.add_text(text + "\n")
		_output.pop()
	else:
		_output.add_text(text + "\n")


func _cmd(text: String) -> void:
	_log("> " + text, COLOR_CMD)


func _ok(text: String) -> void:
	_log("OK  " + text, COLOR_OK)


func _warn(text: String) -> void:
	_log("!!  " + text, COLOR_WARN)


func _error(text: String) -> void:
	_log("ERR " + text, COLOR_ERROR)


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Leaderboard debug (writes to the real Talo backend)"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	_status_label = Label.new()
	vbox.add_child(_status_label)

	_leaderboard_edit = LineEdit.new()
	_leaderboard_edit.text = FinalScreen.TALO_LEADERBOARD
	_add_field(vbox, "Leaderboard", _leaderboard_edit)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Player name"
	_add_field(vbox, "Name", _name_edit)

	_score_spin = SpinBox.new()
	_score_spin.min_value = 0
	_score_spin.max_value = 1_000_000
	_score_spin.step = 1
	_score_spin.value = 999
	_add_field(vbox, "Score (s)", _score_spin)

	var row := _add_row(vbox)
	_add_button(row, "Identify", _on_identify_pressed)
	_add_button(row, "Submit", _on_submit_pressed)
	_add_button(row, "Identify + submit", _on_identify_submit_pressed)

	row = _add_row(vbox)
	_add_button(row, "Refresh", _on_refresh_pressed)
	_prev_button = _add_button(row, "<", _on_page_pressed.bind(-1))
	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_page_label)
	_next_button = _add_button(row, ">", _on_page_pressed.bind(1))
	_archived_check = CheckBox.new()
	_archived_check.text = "Archived"
	row.add_child(_archived_check)

	row = _add_row(vbox)
	_add_button(row, "My entries", _on_mine_pressed)
	_add_button(row, "Top + mine", _on_top_pressed)
	_add_button(row, "Clear log", func() -> void: _output.clear())

	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.context_menu_enabled = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["monospace"])
	_output.add_theme_font_override("normal_font", mono)
	_output.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_output)

	_update_paging()


func _add_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _add_field(parent: Control, label_text: String, field: Control) -> void:
	var row := _add_row(parent)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 110
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button
