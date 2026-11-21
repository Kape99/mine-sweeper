extends "res://Scripts/Tests/test_case.gd"

const SegmentedButton = preload("res://Scripts/GUI/Widgets/segmented_button.gd")

func run() -> void:
	var seg: SegmentedButton = SegmentedButton.new()
	seg.segments = ["Solid", "Wrap"]
	add_child(seg)
	assert_eq(seg._buttons.size(), 2, "creates two buttons")
	assert_eq(seg.selected_index, 0, "default selection is 0")
	assert_eq(seg.get_selected_text(), "Solid", "selected text matches")
	seg._on_button_pressed(1)
	assert_eq(seg.selected_index, 1, "selection updates on press")
	assert_true(seg._buttons[1].button_pressed, "active button is pressed")
	assert_false(seg._buttons[0].button_pressed, "inactive button is not pressed")
	assert_eq(seg.get_selected_text(), "Wrap", "selected text updates")
	seg.queue_free()
