extends Control

const SCHEME_NAMES := ["Teclado", "Mouse + Teclado", "Gamepad", "Tactil"]

var _ship_index: Array[int] = [0, 1]
var _scheme_index: Array[int] = [0, 0]
var _ship_labels: Array[Label] = []
var _scheme_labels: Array[Label] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIHelper.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	var title := UIHelper.make_label("Elegi tu nave", 34, UIHelper.COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var player_count := GameManager.active_player_count()
	for i in player_count:
		vbox.add_child(_build_player_panel(i))

	var start_btn := UIHelper.make_button("Empezar")
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	var back_btn := UIHelper.make_button("Volver")
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _build_player_panel(player_index: int) -> PanelContainer:
	var panel := UIHelper.make_panel()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	vbox.add_child(UIHelper.make_label("Jugador %d" % (player_index + 1), 22, UIHelper.COLOR_ACCENT))

	var ship_row := HBoxContainer.new()
	ship_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev_ship := UIHelper.make_button("<")
	prev_ship.custom_minimum_size = Vector2(56, 56)
	prev_ship.pressed.connect(_cycle_ship.bind(player_index, -1))
	var ship_label := UIHelper.make_label(_ship_display(player_index), 20)
	ship_label.custom_minimum_size = Vector2(220, 0)
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_labels.append(ship_label)
	var next_ship := UIHelper.make_button(">")
	next_ship.custom_minimum_size = Vector2(56, 56)
	next_ship.pressed.connect(_cycle_ship.bind(player_index, 1))
	ship_row.add_child(prev_ship)
	ship_row.add_child(ship_label)
	ship_row.add_child(next_ship)
	vbox.add_child(ship_row)

	var scheme_row := HBoxContainer.new()
	scheme_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev_scheme := UIHelper.make_button("<")
	prev_scheme.custom_minimum_size = Vector2(56, 56)
	prev_scheme.pressed.connect(_cycle_scheme.bind(player_index, -1))
	var scheme_label := UIHelper.make_label(SCHEME_NAMES[_scheme_index[player_index]], 18)
	scheme_label.custom_minimum_size = Vector2(220, 0)
	scheme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scheme_labels.append(scheme_label)
	var next_scheme := UIHelper.make_button(">")
	next_scheme.custom_minimum_size = Vector2(56, 56)
	next_scheme.pressed.connect(_cycle_scheme.bind(player_index, 1))
	scheme_row.add_child(prev_scheme)
	scheme_row.add_child(scheme_label)
	scheme_row.add_child(next_scheme)
	vbox.add_child(scheme_row)

	return panel

func _ship_display(player_index: int) -> String:
	var ship_id: String = GameManager.SHIP_IDS[_ship_index[player_index]]
	var stats := ShipDatabase.get_stats(ship_id)
	return "%s  (vel %.0f / hp %d)" % [stats["display_name"], stats["speed"], stats["max_hp"]]

func _cycle_ship(player_index: int, dir: int) -> void:
	AudioManager.play_sfx("menu_move")
	var count := GameManager.SHIP_IDS.size()
	_ship_index[player_index] = (_ship_index[player_index] + dir + count) % count
	_ship_labels[player_index].text = _ship_display(player_index)

func _cycle_scheme(player_index: int, dir: int) -> void:
	AudioManager.play_sfx("menu_move")
	var count := SCHEME_NAMES.size()
	_scheme_index[player_index] = (_scheme_index[player_index] + dir + count) % count
	_scheme_labels[player_index].text = SCHEME_NAMES[_scheme_index[player_index]]

func _on_start_pressed() -> void:
	AudioManager.play_sfx("menu_confirm")
	var player_count := GameManager.active_player_count()
	for i in player_count:
		GameManager.selected_ship[i] = GameManager.SHIP_IDS[_ship_index[i]]
		GameManager.control_scheme[i] = _scheme_index[i]
	SaveManager.push_checkpoint("Inicio de run")
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
