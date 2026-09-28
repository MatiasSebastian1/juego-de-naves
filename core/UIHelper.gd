class_name UIHelper
extends RefCounted
## Helpers para construir UI por codigo (sin depender de .tscn complejos a
## mano). Estilo simple y oscuro, botones grandes para que funcionen bien
## con dedo en movil.

const COLOR_BG := Color(0.04, 0.045, 0.07)
const COLOR_PANEL := Color(0.09, 0.10, 0.15, 0.92)
const COLOR_ACCENT := Color(0.4, 0.75, 1.0)
const COLOR_TEXT := Color(0.92, 0.94, 0.98)
const COLOR_DANGER := Color(1.0, 0.4, 0.4)

static func make_label(text: String, font_size: int = 20, color: Color = COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func make_button(text: String, font_size: int = 22) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 56)
	button.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.18, 0.28)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.28, 0.42)
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(10)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_ACCENT
	pressed.set_corner_radius_all(10)
	pressed.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button

static func make_panel(color: Color = COLOR_PANEL, radius: int = 14) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func make_background(color: Color = COLOR_BG) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func make_progress_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.14)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar
