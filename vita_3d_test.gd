extends Spatial

export var player_speed := 16.0
export var puck_friction := 1.8
export var shot_force := 30.0

onready var player = $Player
onready var pivot = $Player/Pivot
onready var puck = $Puck
onready var camera = $Camera
onready var debug_label = $UI/DebugLabel

var puck_vel := Vector3.ZERO
var _use_mouse := true

func _ready():
	# Ensure mouse is set up
	if OS.get_name() in ["PSP2", "Vita"]:
		_use_mouse = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		_use_mouse = true
	elif event is InputEventJoypadMotion:
		if event.device == 0 and event.axis in [2, 3] and abs(event.axis_value) > 0.2:
			_use_mouse = false

func _physics_process(delta):
	# 1. Player Movement (WASD / Left Stick)
	var move_dir = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0,
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	
	if move_dir.length() > 0.1:
		player.translation += move_dir.normalized() * player_speed * delta
		
	# Clamp player to rink boundaries
	player.translation.x = clamp(player.translation.x, -39.0, 39.0)
	player.translation.z = clamp(player.translation.z, -19.0, 19.0)
	
	# 2. Stick Rotation (Right Stick / Mouse)
	var stick_input = Vector2(
		Input.get_action_strength("stick_right") - Input.get_action_strength("stick_left"),
		Input.get_action_strength("stick_down") - Input.get_action_strength("stick_up")
	)
	
	if stick_input.length() > 0.2:
		var angle = atan2(-stick_input.y, stick_input.x)
		pivot.rotation.y = angle
	elif _use_mouse:
		var player_screen_pos = camera.unproject_position(player.global_transform.origin)
		var mouse_screen_pos = get_viewport().get_mouse_position()
		var screen_dir = mouse_screen_pos - player_screen_pos
		if screen_dir.length() > 5.0:
			var angle = atan2(-screen_dir.y, screen_dir.x)
			pivot.rotation.y = angle
			
	# 3. Puck Physics
	puck_vel = puck_vel.move_toward(Vector3.ZERO, puck_friction * delta)
	puck.translation += puck_vel * delta
	
	# Puck bounce off walls
	if abs(puck.translation.x) > 39.0:
		puck.translation.x = sign(puck.translation.x) * 39.0
		puck_vel.x = -puck_vel.x * 0.7
	if abs(puck.translation.z) > 19.0:
		puck.translation.z = sign(puck.translation.z) * 19.0
		puck_vel.z = -puck_vel.z * 0.7
		
	# 4. Shooting (Detect if puck is near stick blade)
	var stick_tip = player.global_transform.origin + Vector3.RIGHT.rotated(Vector3.UP, pivot.rotation.y) * 2.0
	var dist_to_puck = stick_tip.distance_to(puck.global_transform.origin)
	
	if Input.is_action_just_pressed("shoot") or Input.is_mouse_button_pressed(BUTTON_LEFT):
		if dist_to_puck < 2.0:
			var shoot_dir = Vector3.RIGHT.rotated(Vector3.UP, pivot.rotation.y)
			puck_vel = shoot_dir * shot_force
			
	# 5. Camera Tracking
	camera.translation.x = lerp(camera.translation.x, player.translation.x, 3.0 * delta)
	camera.translation.z = lerp(camera.translation.z, player.translation.z + 14.0, 3.0 * delta)
	camera.translation.y = 18.0
	
	# 6. Reset Position
	if Input.is_action_just_pressed("reset"):
		player.translation = Vector3.ZERO
		puck.translation = Vector3(0, 0.1, 5)
		puck_vel = Vector3.ZERO
		
	# 7. Update Debug Overlay
	var fps = Engine.get_frames_per_second()
	debug_label.text = (
		"3D Feasibility Test\n" +
		"FPS: %d\n" +
		"Player Pos: (%.1f, %.1f)\n" +
		"Puck Pos: (%.1f, %.1f)\n" +
		"Dist to Puck: %.1f\n" +
		"Controls:\n" +
		"  Move: WASD / Left Stick\n" +
		"  Stick: Mouse / Right Stick\n" +
		"  Shoot: Left Click / Space / Circle\n" +
		"  Reset: R / Start"
	) % [fps, player.translation.x, player.translation.z, puck.translation.x, puck.translation.z, dist_to_puck]
