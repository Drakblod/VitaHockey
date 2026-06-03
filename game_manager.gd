extends Node

var _use_mouse := true

# Broadcast view control options & debugs
var broadcast_invert_x := false
var broadcast_invert_y := false
var broadcast_swap_axes := false

var debug_raw_input := Vector2.ZERO
var debug_cam_rel_input := Vector2.ZERO
var debug_world_input := Vector2.ZERO

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
			
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_I:
			broadcast_invert_x = not broadcast_invert_x
			print("broadcast_invert_x toggled to: ", broadcast_invert_x)
		elif event.scancode == KEY_O:
			broadcast_invert_y = not broadcast_invert_y
			print("broadcast_invert_y toggled to: ", broadcast_invert_y)
		elif event.scancode == KEY_P:
			broadcast_swap_axes = not broadcast_swap_axes
			print("broadcast_swap_axes toggled to: ", broadcast_swap_axes)

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
			
	check_perspective_toggle()

# --- Input Abstraction Layer ---

func get_world_direction_from_screen_input(screen_input: Vector2) -> Vector2:
	if current_view_mode != ViewMode.BROADCAST_VIEW:
		return screen_input
		
	var sx = screen_input.x
	var sy = screen_input.y
	
	if broadcast_invert_x:
		sx = -sx
	if broadcast_invert_y:
		sy = -sy
		
	if broadcast_swap_axes:
		return Vector2(sx, sy)
	else:
		return Vector2(-sy, sx)

func get_skate_input() -> Vector2:
	var raw_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	
	if raw_dir.length() > 1.0:
		raw_dir = raw_dir.normalized()
		
	debug_raw_input = raw_dir
	debug_cam_rel_input = raw_dir
	
	var world_dir = get_world_direction_from_screen_input(raw_dir)
	debug_world_input = world_dir
	
	if world_dir.length() > 0.1:
		return world_dir.normalized()
	return Vector2.ZERO

func get_stick_input(player_global_pos: Vector2) -> Vector2:
	var stick_input = Vector2(
		Input.get_action_strength("stick_right") - Input.get_action_strength("stick_left"),
		Input.get_action_strength("stick_down") - Input.get_action_strength("stick_up")
	)
	
	if stick_input.length() > 0.2:
		return get_world_direction_from_screen_input(stick_input).normalized()
		
	if _use_mouse:
		var player_node = get_tree().root.find_node("Player", true, false) as CanvasItem
		if player_node:
			var player_screen_pos = player_node.get_global_transform_with_canvas().origin
			var mouse_screen_pos = get_viewport().get_mouse_position()
			var screen_dir = (mouse_screen_pos - player_screen_pos)
			if screen_dir.length() > 0.0:
				var screen_dir_norm = screen_dir.normalized()
				if current_view_mode == ViewMode.BROADCAST_VIEW:
					return get_world_direction_from_screen_input(screen_dir_norm).normalized()
				# Non-broadcast view modes:
				var canvas_transform = get_viewport().get_canvas_transform()
				var global_mouse_pos = canvas_transform.affine_inverse().xform(mouse_screen_pos)
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
	if Input.is_joy_button_pressed(0, JOY_BUTTON_4): # JOY_BUTTON_4 is L shoulder button on Vita
		return false
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
			{"type": "joy_button", "val": JOY_BUTTON_1} # Circle on Vita / B on Xbox
		],
		"pass": [
			{"type": "key", "val": KEY_C},
			{"type": "joy_button", "val": JOY_BUTTON_0}, # Cross on Vita / A on Xbox
			{"type": "joy_button", "val": JOY_BUTTON_3}, # Square / X
			{"type": "joy_button", "val": JOY_BUTTON_4}  # L1
		],
		"sprint": [
			{"type": "key", "val": KEY_SHIFT},
			{"type": "joy_button", "val": JOY_BUTTON_5}  # R1 on Vita
		],
		"reset": [
			{"type": "key", "val": KEY_R},
			{"type": "joy_button", "val": JOY_BUTTON_11} # Start Button on Vita
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


# --- Perspective 2.5D Projection System ---
enum ViewMode {
	TOP_DOWN,
	FAKE_2_5D,
	DYNAMIC,
	BROADCAST_VIEW
}

var current_view_mode: int = ViewMode.BROADCAST_VIEW

func project_position(pos: Vector2) -> Vector2:
	match current_view_mode:
		ViewMode.FAKE_2_5D:
			var t = (pos.y + 400.0) / 800.0
			var scale = lerp(0.85, 1.15, t)
			return Vector2(pos.x * scale, pos.y)
		ViewMode.DYNAMIC:
			var t = (pos.x + 800.0) / 1600.0
			var scale = lerp(1.15, 0.85, t)
			return Vector2(pos.x, pos.y * scale)
		ViewMode.BROADCAST_VIEW:
			var scale = lerp(1.10, 0.85, (pos.x + 800.0) / 1600.0)
			return Vector2(pos.y * scale, -pos.x * 0.55)
		_:
			return pos

func get_depth_scale(pos: Vector2) -> float:
	match current_view_mode:
		ViewMode.FAKE_2_5D:
			var t = (pos.y + 400.0) / 800.0
			return lerp(0.85, 1.15, t)
		ViewMode.DYNAMIC:
			var t = (pos.x + 800.0) / 1600.0
			return lerp(1.15, 0.85, t)
		ViewMode.BROADCAST_VIEW:
			return lerp(1.10, 0.85, (pos.x + 800.0) / 1600.0)
		_:
			return 1.0

func set_view_mode(mode: int):
	current_view_mode = mode
	# Trigger redraw for Rink
	var rink = get_tree().root.find_node("Rink", true, false)
	if rink:
		rink.update()
	var puck = get_tree().root.find_node("Puck", true, false)
	if puck:
		puck.update()
	var players = get_tree().get_nodes_in_group("blue_team")
	for p in players:
		p.update()
	var defender = get_tree().root.find_node("Defender", true, false)
	if defender:
		defender.update()
	var goalie = get_tree().root.find_node("Goalie", true, false)
	if goalie:
		goalie.update()

func check_perspective_toggle():
	# PC View toggles: F1 (Top down), F2 (Perspective), F3 (Dynamic), F4 (Broadcast)
	if Input.is_key_pressed(KEY_F1):
		if current_view_mode != ViewMode.TOP_DOWN:
			set_view_mode(ViewMode.TOP_DOWN)
	elif Input.is_key_pressed(KEY_F2):
		if current_view_mode != ViewMode.FAKE_2_5D:
			set_view_mode(ViewMode.FAKE_2_5D)
	elif Input.is_key_pressed(KEY_F3):
		if current_view_mode != ViewMode.DYNAMIC:
			set_view_mode(ViewMode.DYNAMIC)
	elif Input.is_key_pressed(KEY_F4):
		if current_view_mode != ViewMode.BROADCAST_VIEW:
			set_view_mode(ViewMode.BROADCAST_VIEW)
			
	# PS Vita/Controller toggle: L (JOY_BUTTON_4) + SELECT (toggle_opponent)
	if Input.is_joy_button_pressed(0, JOY_BUTTON_4) and Input.is_action_just_pressed("toggle_opponent"):
		var next_mode = (current_view_mode + 1) % 4
		set_view_mode(next_mode)

