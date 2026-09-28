extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIHelper.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	vbox.add_child(UIHelper.make_label("Ranking local", 32, UIHelper.COLOR_ACCENT))
	vbox.add_child(_spacer(16))

	var entries := SaveManager.load_ranking()
	if entries.is_empty():
		vbox.add_child(UIHelper.make_label("Todavia no hay puntajes.", 18))
	else:
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var name_str: String = String(entry.get("name", "???")).rpad(12)
			var line := "%d. %s %d pts (nivel %d)" % [i + 1, name_str, int(entry.get("score", 0)), int(entry.get("level_reached", 1))]
			vbox.add_child(UIHelper.make_label(line, 16))

	vbox.add_child(_spacer(20))
	var back_btn := UIHelper.make_button("Volver")
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	vbox.add_child(back_btn)

func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
