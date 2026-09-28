extends Control

var _name_edit: LineEdit
var _save_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIHelper.make_background())

	var result: Dictionary = GameManager.last_result
	var result_type := String(result.get("type", "level_complete"))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UIHelper.make_panel()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	match result_type:
		"level_complete":
			vbox.add_child(UIHelper.make_label("Nivel %d completado" % int(result.get("level_id", 1)), 28, UIHelper.COLOR_ACCENT))
		"victory":
			vbox.add_child(UIHelper.make_label("Requiem completado", 28, UIHelper.COLOR_ACCENT))
		_:
			vbox.add_child(UIHelper.make_label("Game Over", 28, UIHelper.COLOR_DANGER))

	var scores: Array = result.get("scores", GameManager.scores)
	for i in scores.size():
		if i < GameManager.active_player_count():
			vbox.add_child(UIHelper.make_label("Jugador %d: %d puntos" % [i + 1, int(scores[i])], 18))

	if result_type != "level_complete":
		vbox.add_child(_build_ranking_entry(int(scores[0]) if scores.size() > 0 else 0, int(result.get("level_id", 1))))

	if result_type == "level_complete":
		var continue_btn := UIHelper.make_button("Continuar")
		continue_btn.pressed.connect(_on_continue_pressed)
		vbox.add_child(continue_btn)
	else:
		var ranking_btn := UIHelper.make_button("Ver ranking")
		ranking_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ranking/Ranking.tscn"))
		vbox.add_child(ranking_btn)

		var menu_btn := UIHelper.make_button("Menu principal")
		menu_btn.pressed.connect(_on_menu_pressed)
		vbox.add_child(menu_btn)

func _build_ranking_entry(score: int, level_reached: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size = Vector2(160, 44)
	box.add_child(_name_edit)
	_save_btn = UIHelper.make_button("Guardar")
	_save_btn.custom_minimum_size = Vector2(100, 44)
	_save_btn.pressed.connect(func():
		SaveManager.submit_ranking_entry(_name_edit.text, score, level_reached)
		_save_btn.disabled = true
		_save_btn.text = "Guardado"
	)
	box.add_child(_save_btn)
	return box

func _on_continue_pressed() -> void:
	GameManager.current_level_id = clampi(int(GameManager.last_result.get("level_id", 1)) + 1, 1, GameManager.MAX_LEVEL)
	SaveManager.push_checkpoint("Nivel %d" % GameManager.current_level_id)
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
