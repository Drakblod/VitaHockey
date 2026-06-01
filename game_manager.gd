extends Node

var _use_mouse := true

# Sprint tap tracking
var _sprint_held_time := 0.0
var _sprint_was_pressed := false
var _sprint_tapped := false

func _ready():
	_setup_inputs()
	if OS.get_name() in ["PSP2", "Vita"]:
		_use_mouse = false

func _input(event):
	if event is InputEventMouseMotion:
		_use_mouse = true
	elif event is InputEventJoypadMotion:
		if event.axis in [2, 3] and abs(event.axis_value) > 0.2:
			_use_mouse = false

func _physics_process(delta):
	# Update sprint tap/hold state machine
	_sprint_tapped = false
	if Input.is_action_pressed("sprint"):
		if not _sprint_was_pressed:
			_sprint_was_pressed = true
			_sprint_held_time = 0.0
		else:
			_sprint_held_time += delta
	else:
		if _sprint_was_pressed:
			if _sprint_held_time < 0.22:
				_sprint_tapped = true
			_sprint_was_pressed = false
			_sprint_held_time = 0.0

# --- Input Abstraction Layer ---

func get_skate_input() -> Vector2:
	var move_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if move_dir.length() > 0.1:
		return move_dir.normalized()
	return Vector2.ZERO

func get_stick_input(player_global_pos: Vector2) -> Vector2:
	var stick_input = Vector2(
		Input.get_action_strength("stick_right") - Input.get_action_strength("stick_left"),
		Input.get_action_strength("stick_down") - Input.get_action_strength("stick_up")
	)
	
	if stick_input.length() > 0.2:
		return stick_input.normalized()
		
	if _use_mouse:
		var canvas_transform = get_viewport().get_canvas_transform()
		var global_mouse_pos = canvas_transform.affine_inverse().xform(get_viewport().get_mouse_position())
		return (global_mouse_pos - player_global_pos).normalized()
		
	return Vector2.ZERO

func is_shoot_pressed() -> bool:
	return Input.is_action_just_pressed("shoot")

func is_shoot_held() -> bool:
	return Input.is_action_pressed("shoot")

func is_shoot_released() -> bool:
	return Input.is_action_just_released("shoot")

func is_pass_pressed() -> bool:
	return Input.is_action_just_pressed("pass")

func is_sprint_held() -> bool:
	return Input.is_action_pressed("sprint")

func is_sprint_tapped() -> bool:
	return _sprint_tapped

func is_reset_pressed() -> bool:
	return Input.is_action_just_pressed("reset")

func is_mouse_aiming() -> bool:
	return _use_mouse

func is_toggle_opponent_pressed() -> bool:
	return Input.is_action_just_pressed("toggle_opponent")

# --- Default Input Mapping Setup ---

func _setup_inputs():
	var inputs = {
		"move_left": [
			{"type": "key", "val": KEY_A},
			{"type": "joy_motion", "axis": 0, "val": -1.0}
		],
		"move_right": [
			{"type": "key", "val": KEY_D},
			{"type": "joy_motion", "axis": 0, "val": 1.0}
		],
		"move_up": [
			{"type": "key", "val": KEY_W},
			{"type": "joy_motion", "axis": 1, "val": -1.0}
		],
		"move_down": [
			{"type": "key", "val": KEY_S},
			{"type": "joy_motion", "axis": 1, "val": 1.0}
		],
		"stick_left": [
			{"type": "key", "val": KEY_LEFT},
			{"type": "joy_motion", "axis": 2, "val": -1.0}
		],
		"stick_right": [
			{"type": "key", "val": KEY_RIGHT},
			{"type": "joy_motion", "axis": 2, "val": 1.0}
		],
		"stick_up": [
			{"type": "key", "val": KEY_UP},
			{"type": "joy_motion", "axis": 3, "val": -1.0}
		],
		"stick_down": [
			{"type": "key", "val": KEY_DOWN},
			{"type": "joy_motion", "axis": 3, "val": 1.0}
		],
		"shoot": [
			{"type": "key", "val": KEY_SPACE},
			{"type": "mouse", "val": BUTTON_LEFT},
			{"type": "joy_button", "val": JOY_BUTTON_0}
		],
		"pass": [
			{"type": "key", "val": KEY_C},
			{"type": "joy_button", "val": JOY_BUTTON_2}, # Square / X
			{"type": "joy_button", "val": JOY_BUTTON_4}  # L1
		],
		"sprint": [
			{"type": "key", "val": KEY_SHIFT},
			{"type": "joy_button", "val": JOY_BUTTON_5}  # R1 (re-mapped to sprint)
		],
		"reset": [
			{"type": "key", "val": KEY_R},
			{"type": "joy_button", "val": JOY_BUTTON_11} # Start Button
		],
		"toggle_opponent": [
			{"type": "key", "val": KEY_O},
			{"type": "joy_button", "val": JOY_BUTTON_10} # Select Button
		],
		"toggle_debug": [
			{"type": "key", "val": KEY_K}
		]
	}

	for action in inputs.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		for ev in InputMap.get_action_list(action):
			InputMap.action_erase_event(action, ev)
			
		for data in inputs[action]:
			var event
			if data["type"] == "key":
				event = InputEventKey.new()
				event.scancode = data["val"]
			elif data["type"] == "joy_motion":
				event = InputEventJoypadMotion.new()
				event.device = 0
				event.axis = data["axis"]
				event.axis_value = data["val"]
			elif data["type"] == "mouse":
				event = InputEventMouseButton.new()
				event.button_index = data["val"]
				event.pressed = true
			elif data["type"] == "joy_button":
				event = InputEventJoypadButton.new()
				event.device = 0
				event.button_index = data["val"]
				event.pressed = true
			
			if event:
				InputMap.action_add_event(action, event)
