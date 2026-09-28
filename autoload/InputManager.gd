extends Node
## InputManager: abstrae teclado, mouse, gamepad y tactil para hasta 2 jugadores.
## Los esquemas de control se leen desde GameManager.control_scheme[player_index].

const SCHEME_KEYBOARD := 0
const SCHEME_MOUSE_KEYBOARD := 1
const SCHEME_GAMEPAD := 2
const SCHEME_TOUCH := 3

var _touch_points: Dictionary = {} # touch_index -> Vector2 screen pos
var _touch_owner_by_player: Dictionary = {} # player_index -> touch_index

func _ready() -> void:
	_setup_actions()

func _setup_actions() -> void:
	_add_key_action("p1_left", KEY_A)
	_add_key_action("p1_right", KEY_D)
	_add_key_action("p1_up", KEY_W)
	_add_key_action("p1_down", KEY_S)
	_add_key_action("p1_fire", KEY_SPACE)
	_add_key_action("p1_bomb", KEY_SHIFT)

	_add_key_action("p2_left", KEY_LEFT)
	_add_key_action("p2_right", KEY_RIGHT)
	_add_key_action("p2_up", KEY_UP)
	_add_key_action("p2_down", KEY_DOWN)
	_add_key_action("p2_fire", KEY_ENTER)
	_add_key_action("p2_bomb", KEY_CTRL)

	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("p1_fire_mouse", KEY_NONE)
	_add_mouse_action("p1_fire_mouse", MOUSE_BUTTON_LEFT)

	_add_joy_axis_action("p1_left", 0, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("p1_right", 0, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("p1_up", 0, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("p1_down", 0, JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button_action("p1_fire", 0, JOY_BUTTON_A)
	_add_joy_button_action("p1_bomb", 0, JOY_BUTTON_B)
	_add_joy_button_action("pause", 0, JOY_BUTTON_START)

	_add_joy_axis_action("p2_left", 1, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("p2_right", 1, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("p2_up", 1, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("p2_down", 1, JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button_action("p2_fire", 1, JOY_BUTTON_A)
	_add_joy_button_action("p2_bomb", 1, JOY_BUTTON_B)

func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if keycode == KEY_NONE:
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_mouse_action(action: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)

func _add_joy_button_action(action: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_joy_axis_action(action: String, device: int, axis: JoyAxis, axis_value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action, ev)

## --- API publica por jugador --------------------------------------------

func get_move_vector(player_index: int) -> Vector2:
	var prefix := "p1_" if player_index == 0 else "p2_"
	return Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")

func is_fire_held(player_index: int) -> bool:
	var prefix := "p1_" if player_index == 0 else "p2_"
	if Input.is_action_pressed(prefix + "fire"):
		return true
	if player_index == 0 and _scheme(0) == SCHEME_MOUSE_KEYBOARD:
		return Input.is_action_pressed("p1_fire_mouse")
	if player_index == 0 and _scheme(0) == SCHEME_TOUCH:
		return _touch_owner_by_player.has(0)
	if player_index == 1 and _scheme(1) == SCHEME_TOUCH:
		return _touch_owner_by_player.has(1)
	return false

func is_bomb_just_pressed(player_index: int) -> bool:
	var prefix := "p1_" if player_index == 0 else "p2_"
	return Input.is_action_just_pressed(prefix + "bomb")

func is_pause_just_pressed() -> bool:
	return Input.is_action_just_pressed("pause")

func has_direct_position_control(player_index: int) -> bool:
	return _scheme(player_index) == SCHEME_TOUCH

func get_touch_target_position(player_index: int) -> Vector2:
	var touch_index = _touch_owner_by_player.get(player_index, -1)
	if touch_index == -1 or not _touch_points.has(touch_index):
		return Vector2.ZERO
	return _touch_points[touch_index]

func wants_mouse_aim(player_index: int) -> bool:
	return player_index == 0 and _scheme(0) == SCHEME_MOUSE_KEYBOARD

func get_mouse_screen_position() -> Vector2:
	return get_viewport().get_mouse_position() if get_viewport() else Vector2.ZERO

func _scheme(player_index: int) -> int:
	if player_index < 0 or player_index >= GameManager.control_scheme.size():
		return SCHEME_KEYBOARD
	return GameManager.control_scheme[player_index]

## --- Tactil ----------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
			_assign_touch_to_free_player(event.index)
		else:
			_touch_points.erase(event.index)
			for p in _touch_owner_by_player.keys():
				if _touch_owner_by_player[p] == event.index:
					_touch_owner_by_player.erase(p)
	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position

func _assign_touch_to_free_player(touch_index: int) -> void:
	for p in range(GameManager.active_player_count()):
		if _scheme(p) == SCHEME_TOUCH and not _touch_owner_by_player.has(p):
			_touch_owner_by_player[p] = touch_index
			return
