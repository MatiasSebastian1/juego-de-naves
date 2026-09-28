extends CanvasLayer

signal resume_requested
signal revert_requested
signal restart_requested
signal quit_requested

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)
	root.add_child(UIHelper.make_background(Color(0.02, 0.02, 0.04, 0.85)))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(center)

	var panel := UIHelper.make_panel()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	vbox.add_child(UIHelper.make_label("Pausa", 30, UIHelper.COLOR_ACCENT))

	var resume_btn := UIHelper.make_button("Reanudar")
	resume_btn.pressed.connect(func(): resume_requested.emit())
	vbox.add_child(resume_btn)

	if SaveManager.has_checkpoints():
		var revert_btn := UIHelper.make_button("Volver a punto anterior")
		revert_btn.pressed.connect(func(): revert_requested.emit())
		vbox.add_child(revert_btn)

	var restart_btn := UIHelper.make_button("Reiniciar nivel")
	restart_btn.pressed.connect(func(): restart_requested.emit())
	vbox.add_child(restart_btn)

	var quit_btn := UIHelper.make_button("Salir al menu")
	quit_btn.pressed.connect(func(): quit_requested.emit())
	vbox.add_child(quit_btn)
