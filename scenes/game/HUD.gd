extends CanvasLayer

var _hp_bars: Array[ProgressBar] = []
var _score_labels: Array[Label] = []
var _lives_labels: Array[Label] = []
var _bomb_labels: Array[Label] = []
var _weapon_labels: Array[Label] = []
var _shield_labels: Array[Label] = []

var _boss_bar: ProgressBar
var _boss_panel: Control
var _phase_label: Label
var _phase_tween: Tween

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 14)
	top_margin.add_theme_constant_override("margin_right", 14)
	top_margin.add_theme_constant_override("margin_top", 14)
	root.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	top_margin.add_child(top_vbox)

	var player_count := GameManager.active_player_count()
	for i in player_count:
		top_vbox.add_child(_build_player_row(i))

	_boss_panel = MarginContainer.new()
	_boss_panel.add_theme_constant_override("margin_top", 8)
	_boss_panel.visible = false
	top_vbox.add_child(_boss_panel)
	var boss_vbox := VBoxContainer.new()
	_boss_panel.add_child(boss_vbox)
	_phase_label = UIHelper.make_label("", 16, UIHelper.COLOR_DANGER)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_vbox.add_child(_phase_label)
	_boss_bar = UIHelper.make_progress_bar(UIHelper.COLOR_DANGER)
	_boss_bar.custom_minimum_size = Vector2(0, 14)
	boss_vbox.add_child(_boss_bar)

func _build_player_row(player_index: int) -> PanelContainer:
	var panel := UIHelper.make_panel(Color(0.08, 0.09, 0.13, 0.75), 8)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	var label_p := UIHelper.make_label("P%d" % (player_index + 1), 16, UIHelper.COLOR_ACCENT)
	hbox.add_child(label_p)

	var hp_bar := UIHelper.make_progress_bar(Color(0.4, 0.9, 0.5))
	hp_bar.custom_minimum_size = Vector2(90, 14)
	_hp_bars.append(hp_bar)
	hbox.add_child(hp_bar)

	var lives_label := UIHelper.make_label("x3", 16)
	_lives_labels.append(lives_label)
	hbox.add_child(lives_label)

	var shield_label := UIHelper.make_label("S:0", 16, Color(0.4, 0.7, 1.0))
	_shield_labels.append(shield_label)
	hbox.add_child(shield_label)

	var bomb_label := UIHelper.make_label("B:2", 16, Color(1.0, 0.6, 0.5))
	_bomb_labels.append(bomb_label)
	hbox.add_child(bomb_label)

	var weapon_label := UIHelper.make_label("W1", 16, Color(1.0, 0.9, 0.3))
	_weapon_labels.append(weapon_label)
	hbox.add_child(weapon_label)

	var score_label := UIHelper.make_label("0", 16)
	_score_labels.append(score_label)
	hbox.add_child(score_label)

	return panel

func bind_player(player_index: int, player: Node) -> void:
	player.hp_changed.connect(_on_hp_changed.bind(player_index))
	player.shield_changed.connect(_on_shield_changed.bind(player_index))
	_on_hp_changed(player.current_hp, player.max_hp, player_index)
	_on_shield_changed(GameManager.shield_charges[player_index], player_index)
	_update_side_stats(player_index)

func bind_game_manager_signals() -> void:
	GameManager.score_changed.connect(func(idx, val): _score_labels[idx].text = str(val))
	GameManager.lives_changed.connect(func(idx, val): _lives_labels[idx].text = "x%d" % val)

func bind_level(level: Node) -> void:
	level.boss_spawned.connect(_on_boss_spawned)
	level.boss_phase_changed.connect(_on_boss_phase_changed)

func _on_hp_changed(current: int, max_hp: int, player_index: int) -> void:
	if player_index >= _hp_bars.size():
		return
	_hp_bars[player_index].value = float(current) / float(max(max_hp, 1))

func _on_shield_changed(charges: int, player_index: int) -> void:
	if player_index >= _shield_labels.size():
		return
	_shield_labels[player_index].text = "S:%d" % charges

func _update_side_stats(player_index: int) -> void:
	if player_index >= _bomb_labels.size():
		return
	_bomb_labels[player_index].text = "B:%d" % GameManager.bombs[player_index]
	_weapon_labels[player_index].text = "W%d" % GameManager.weapon_level[player_index]
	_score_labels[player_index].text = str(GameManager.scores[player_index])
	_lives_labels[player_index].text = "x%d" % GameManager.lives[player_index]

func _process(_delta: float) -> void:
	for i in _bomb_labels.size():
		_update_side_stats(i)

func _on_boss_spawned(boss: Node) -> void:
	_boss_panel.visible = true
	boss.boss_hp_changed.connect(func(frac): _boss_bar.value = frac)

func _on_boss_phase_changed(_index: int, phase_name: String) -> void:
	_phase_label.text = phase_name
	if _phase_tween:
		_phase_tween.kill()
	_phase_label.modulate.a = 1.0
	_phase_tween = create_tween()
	_phase_tween.tween_interval(1.5)
	_phase_tween.tween_property(_phase_label, "modulate:a", 0.4, 0.5)
