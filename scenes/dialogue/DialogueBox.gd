extends CanvasLayer

signal finished

var _lines: Array = []
var _index: int = 0
var _portrait: ColorRect
var _speaker_label: Label
var _text_label: Label
var _hint_label: Label

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_lines(lines: Array) -> void:
	_lines = lines
	_index = 0
	_build_ui()
	if _lines.is_empty():
		_close()
		return
	_render_current()
	visible = true

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_gui_input)
	add_child(root)
	root.add_child(UIHelper.make_background(Color(0, 0, 0, 0.55)))

	var bottom_margin := MarginContainer.new()
	bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_margin.add_theme_constant_override("margin_left", 20)
	bottom_margin.add_theme_constant_override("margin_right", 20)
	bottom_margin.add_theme_constant_override("margin_bottom", 40)
	root.add_child(bottom_margin)

	var panel := UIHelper.make_panel()
	bottom_margin.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(56, 56)
	_portrait.color = Color.WHITE
	hbox.add_child(_portrait)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_speaker_label = UIHelper.make_label("", 18, UIHelper.COLOR_ACCENT)
	vbox.add_child(_speaker_label)

	_text_label = UIHelper.make_label("", 18)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_text_label)

	_hint_label = UIHelper.make_label("Toca para continuar", 13, Color(0.6, 0.6, 0.7))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint_label)

func _render_current() -> void:
	var line: Dictionary = _lines[_index]
	_speaker_label.text = String(line.get("speaker", ""))
	_text_label.text = String(line.get("text", ""))
	_portrait.color = line.get("color", Color.WHITE)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()

func _physics_process(_delta: float) -> void:
	# Se usa polling (no _unhandled_input) para que el avance por
	# teclado/gamepad sea confiable incluso con la pausa activa mientras
	# se lee el dialogo.
	if not visible:
		return
	if Input.is_action_just_pressed("p1_fire") or Input.is_action_just_pressed("pause"):
		_advance()

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_render_current()

func _close() -> void:
	visible = false
	finished.emit()
