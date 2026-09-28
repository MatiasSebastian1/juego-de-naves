extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIHelper.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title := UIHelper.make_label("REQUIEM", 56, UIHelper.COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := UIHelper.make_label("Shoot 'em up vertical", 18, Color(0.7, 0.75, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(40))

	if SaveManager.has_checkpoints():
		var continue_btn := UIHelper.make_button("Continuar")
		continue_btn.pressed.connect(_on_continue_pressed)
		vbox.add_child(continue_btn)

	var play_btn := UIHelper.make_button("Jugar (1 jugador)")
	play_btn.pressed.connect(_on_play_pressed.bind(GameManager.GameMode.SOLO))
	vbox.add_child(play_btn)

	var coop_btn := UIHelper.make_button("Cooperativo (2 jugadores)")
	coop_btn.pressed.connect(_on_play_pressed.bind(GameManager.GameMode.COOP))
	vbox.add_child(coop_btn)

	var ranking_btn := UIHelper.make_button("Ranking")
	ranking_btn.pressed.connect(_on_ranking_pressed)
	vbox.add_child(ranking_btn)

	var quit_btn := UIHelper.make_button("Salir")
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _on_play_pressed(mode: int) -> void:
	AudioManager.play_sfx("menu_confirm")
	GameManager.reset_run(mode)
	get_tree().change_scene_to_file("res://scenes/ship_select/ShipSelect.tscn")

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("menu_confirm")
	SaveManager.revert_to_last()
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_ranking_pressed() -> void:
	AudioManager.play_sfx("menu_move")
	get_tree().change_scene_to_file("res://scenes/ranking/Ranking.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
