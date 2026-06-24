extends Spatial

export var player_speed := 16.0
export var puck_friction := 1.8

# Camera chase configurations
export var camera_height := 14.0
export var camera_distance := 16.0
export var camera_smooth := 6.0
export var camera_look_ahead := 6.0
export var camera_yaw_smooth := 1.2 # Damped camera yaw rotation speed

# Control and Visual options
export var show_stick_visual := true
export var invert_stick_sweep_x := true # Toggle to correct left-right sweep direction

# Puck Sweep reach configurations
export var side_reach := 1.8
export var base_forward := 2.4
export var forward_reach := 0.8

# Clamping boundaries for puck target in front of player
export var min_local_x := -1.8
export var max_local_x := 1.8
export var min_local_z := 1.6
export var max_local_z := 3.2

# Tuning configurations for shooting force/time
export var min_slap_force := 20.0
export var max_slap_force := 36.0
export var max_slap_charge_time := 1.0
export var wrist_shot_force := 16.0
export var shot_cooldown := 0.4 
export var slap_cancel_window := 0.5

# Tuning threshold parameters for shooting
export var pull_load_threshold := 0.45 
export var flick_release_threshold := -0.25 
export var wrist_release_threshold := -0.45 
export var flick_velocity_threshold := -3.0
export var flick_time_window := 0.35

onready var player = $Player
onready var body_mesh = $Player/MeshInstance
onready var pivot = $Player/MeshInstance/Pivot
onready var stick = $Player/MeshInstance/Pivot/Stick
onready var blade_target = $Player/MeshInstance/BladeTarget
onready var puck = $Puck
onready var camera = $Camera
onready var debug_label = $UI/DebugLabel

# Enums and States
enum PuckState { FREE, POSSESSED }
var current_puck_state = PuckState.FREE
var puck_vel := Vector3.ZERO
var _use_mouse := false

export var capture_radius := 0.65
export var shot_recapture_delay := 0.25
export var puck_ice_height := 0.125

export var puck_gravity := 24.0
export var wrist_shot_lift := 3.0
export var slapshot_min_lift := 4.0
export var slapshot_max_lift := 8.0
export var puck_vertical_bounce := 0.2
export var enable_shot_elevation := true

var recapture_timer := 0.0
var puck_vertical_velocity := 0.0
var last_shot_lift := 0.0

# Refactored ShotState Enum
enum ShotState { CARRY, SLAP_LOADING, RELEASED, CANCELLED }
var current_shot_state = ShotState.CARRY

# Shot machine tracking variables
var slap_charge := 0.0
var slap_charge_percent := 0.0
var prev_stick_raw_y := 0.0
var stick_y_velocity := 0.0
var shot_cooldown_timer := 0.0
var cancel_timer := 0.0

var last_shot_type := "NONE"
var last_shot_force := 0.0
var last_shot_dir := Vector3.ZERO
var did_release_shot_this_frame := false

var front_marker_material : SpatialMaterial
var current_look_at := Vector3.ZERO
var cam_yaw := 0.0 # Damped camera yaw angle

# Class-level sweep coordinates
var local_x := 0.0
var local_z := 1.8

func _ready():
	if OS.get_name() in ["PSP2", "Vita"]:
		_use_mouse = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	camera.make_current()
	
	# Set up a unique unshaded material for the front marker so we can color it dynamically
	front_marker_material = SpatialMaterial.new()
	front_marker_material.flags_unshaded = true
	front_marker_material.albedo_color = Color(1.0, 1.0, 1.0)
	var marker_node = player.get_node_or_null("MeshInstance/FrontMarker")
	if marker_node:
		marker_node.set_material_override(front_marker_material)
		
	# Initialize chase camera looking behind the player
	cam_yaw = body_mesh.rotation.y
	var initial_body_face_dir = Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()
	camera.translation = player.translation - initial_body_face_dir * camera_distance + Vector3(0, camera_height, 0)
	current_look_at = player.translation
	camera.look_at(current_look_at, Vector3.UP)
	
	# Initialize local coordinates
	local_x = 0.0
	local_z = base_forward

func _input(event):
	pass

# Shot release helper function
func _release_shot(force: float, shot_type: String):
	# Calculate shot direction: vector from player body center to current puck position
	var shot_dir = puck.global_transform.origin - player.global_transform.origin
	shot_dir.y = 0 # flatten Y
	
	if shot_dir.length() < 0.1:
		# Fallback to player body forward if vector is too short
		var body_angle = body_mesh.rotation.y
		shot_dir = Vector3(sin(body_angle), 0, cos(body_angle))
	else:
		shot_dir = shot_dir.normalized()
		
	# Move released puck beyond capture_radius
	puck.global_transform.origin += shot_dir * (capture_radius + 0.15)
	
	puck_vel = shot_dir * force
	current_puck_state = PuckState.FREE
	current_shot_state = ShotState.RELEASED
	
	# Determine vertical shot elevation lift before clearing charge percentages
	if enable_shot_elevation:
		if "WRIST" in shot_type:
			puck_vertical_velocity = wrist_shot_lift
		elif "SLAP" in shot_type:
			var t = slap_charge_percent / 100.0
			puck_vertical_velocity = lerp(slapshot_min_lift, slapshot_max_lift, t)
		else:
			puck_vertical_velocity = 0.0
	else:
		puck_vertical_velocity = 0.0
		
	last_shot_lift = puck_vertical_velocity
	last_shot_type = shot_type
	last_shot_force = force
	last_shot_dir = shot_dir
	
	slap_charge = 0.0
	slap_charge_percent = 0.0
	shot_cooldown_timer = shot_cooldown
	recapture_timer = shot_recapture_delay
	did_release_shot_this_frame = true

func _physics_process(delta):
	var fps = Engine.get_frames_per_second()
	
	# Hide/show stick visual based on configuration
	stick.visible = show_stick_visual
	
	# Cooldown / recapture timer tracking
	if shot_cooldown_timer > 0.0:
		shot_cooldown_timer -= delta
	if recapture_timer > 0.0:
		recapture_timer -= delta
	if cancel_timer > 0.0:
		cancel_timer -= delta
		
	# 1. Read input & Player Skating Movement (WASD / Left Stick - Camera Relative)
	var input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z = Input.get_action_strength("move_up") - Input.get_action_strength("move_down") # W = +1 (forward), S = -1 (backward)
	
	var cam_basis = camera.global_transform.basis
	var cam_forward = -cam_basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	
	var cam_right = cam_basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()
	
	var move_dir = Vector3.ZERO
	if abs(input_x) > 0.1 or abs(input_z) > 0.1:
		move_dir = (cam_right * input_x + cam_forward * input_z).normalized()
		var player_vel = move_dir * player_speed
		player.translation += player_vel * delta
		
	# Smoothly rotate player body to face skating direction (only when moving), but NOT during slap wind-up
	if move_dir.length() > 0.1 and not (current_shot_state == ShotState.SLAP_LOADING):
		var target_angle = atan2(move_dir.x, move_dir.z)
		body_mesh.rotation.y = lerp_angle(body_mesh.rotation.y, target_angle, 10.0 * delta)
		
	# Clamp player to rink boundaries (rink size is 80x40)
	player.translation.x = clamp(player.translation.x, -39.0, 39.0)
	player.translation.z = clamp(player.translation.z, -19.0, 19.0)
	
	# Compute body facing direction vector
	var body_angle = body_mesh.rotation.y
	var body_face_dir = Vector3(sin(body_angle), 0, cos(body_angle)).normalized()
	
	# Read stick input from actions (InputMap)
	var stick_input = Vector2(
		Input.get_action_strength("stick_right") - Input.get_action_strength("stick_left"),
		Input.get_action_strength("stick_down") - Input.get_action_strength("stick_up") # Down = positive, Up = negative
	)
	
	# Debug-only raw joystick axis values directly from controller (device 0)
	var joy_rx = Input.get_joy_axis(0, JOY_AXIS_2)
	var joy_ry = Input.get_joy_axis(0, JOY_AXIS_3)
	
	# Use InputMap action strengths as gameplay input
	var stick_raw_x = stick_input.x
	var stick_raw_y = stick_input.y
	
	var stick_mag = stick_input.length()
	
	# 2. Update Control Point (BladeTarget & Stick Pivoting)
	var using_neutral_stick := false
	if stick_mag > 0.15:
		# Active stick input
		pass
	else:
		# Neutral stick state: smoothly return stick_raw_x and stick_raw_y to 0
		using_neutral_stick = true
		stick_raw_x = lerp(stick_raw_x, 0.0, 15.0 * delta)
		stick_raw_y = lerp(stick_raw_y, 0.0, 15.0 * delta)
		stick_mag = Vector2(stick_raw_x, stick_raw_y).length()
		
	# Invert X axis if enabled
	var raw_x = stick_raw_x
	if invert_stick_sweep_x:
		raw_x = -raw_x
	
	# Calculate stick Y velocity
	if delta > 0.0:
		stick_y_velocity = (stick_raw_y - prev_stick_raw_y) / delta
	prev_stick_raw_y = stick_raw_y
	
	var target_local_x := 0.0
	var target_local_z := base_forward
	
	if not using_neutral_stick:
		target_local_x = clamp(raw_x * side_reach, min_local_x, max_local_x)
		target_local_z = clamp(base_forward - stick_raw_y * forward_reach, min_local_z, max_local_z)
	else:
		target_local_x = 0.0
		target_local_z = base_forward
		
	# Smoothly interpolate the 2D local coordinate target
	local_x = lerp(local_x, target_local_x, 15.0 * delta)
	local_z = lerp(local_z, target_local_z, 15.0 * delta)
	
	# Update BladeTarget position relative to player body
	blade_target.translation = Vector3(local_x, -1.2, local_z)
	
	# Rotate the pivot to look at the local target
	pivot.rotation.y = atan2(local_x, local_z)
	
	# Keep stick mesh at fixed length, translate so tip reaches exactly the BladeTarget
	var dist = Vector2(local_x, local_z).length()
	stick.scale = Vector3(1.0, 1.0, 1.0)
	stick.translation = Vector3(0.0, -1.2, dist - 1.25)
	
	# 3. Update Capture State
	var dist_to_target = puck.global_transform.origin.distance_to(blade_target.global_transform.origin)
	if current_puck_state == PuckState.FREE:
		# Capture puck if close to BladeTarget and recapture delay has expired
		if dist_to_target < capture_radius and recapture_timer <= 0.0:
			current_puck_state = PuckState.POSSESSED
			current_shot_state = ShotState.CARRY
			# Capture reset: force control point to neutral directly in front of skater
			local_x = 0.0
			local_z = base_forward
			blade_target.translation = Vector3(0.0, -1.2, base_forward)
			puck.global_transform.origin = blade_target.global_transform.origin
			puck.global_transform.origin.y = puck_ice_height
			puck_vertical_velocity = 0.0
			slap_charge = 0.0
			slap_charge_percent = 0.0
			stick_y_velocity = 0.0
			prev_stick_raw_y = 0.0
			dist_to_target = 0.0
			
	elif current_puck_state == PuckState.POSSESSED:
		# Lock puck directly to the local target in body's space (no physics, copy BladeTarget X/Z, force Y to puck_ice_height)
		puck.global_transform.origin.x = blade_target.global_transform.origin.x
		puck.global_transform.origin.z = blade_target.global_transform.origin.z
		puck.global_transform.origin.y = puck_ice_height
		puck_vel = Vector3.ZERO
		puck_vertical_velocity = 0.0
		dist_to_target = puck.global_transform.origin.distance_to(blade_target.global_transform.origin)
		
	# 4. Process Shot State
	# Button wrist shot fallback (Only Input.is_action_just_pressed("shoot") may trigger it)
	var button_shot_pressed = false
	if Input.is_action_just_pressed("shoot"):
		button_shot_pressed = true
		
	if button_shot_pressed and current_puck_state == PuckState.POSSESSED:
		_release_shot(wrist_shot_force, "BUTTON_WRIST")
	else:
		match current_shot_state:
			ShotState.CARRY:
				if current_puck_state == PuckState.POSSESSED and shot_cooldown_timer <= 0.0:
					# Arcade Wrist Shot: raw_y pushed forward past threshold
					if stick_raw_y < wrist_release_threshold:
						_release_shot(wrist_shot_force, "WRIST")
					# Arcade Slapshot: raw_y pulled back past threshold
					elif stick_raw_y > pull_load_threshold:
						current_shot_state = ShotState.SLAP_LOADING
						slap_charge = 0.0
						slap_charge_percent = 0.0
						cancel_timer = 0.0
						
			ShotState.SLAP_LOADING:
				if current_puck_state == PuckState.POSSESSED:
					slap_charge = min(slap_charge + delta, max_slap_charge_time)
					slap_charge_percent = (slap_charge / max_slap_charge_time) * 100.0
					
					# Arcade Slapshot Release: raw_y pushed forward past release threshold
					if stick_raw_y < flick_release_threshold:
						var force = lerp(min_slap_force, max_slap_force, slap_charge / max_slap_charge_time)
						_release_shot(force, "SLAPSHOT")
					else:
						# Cancel tracking: Y returns near center
						if stick_raw_y <= pull_load_threshold:
							cancel_timer += delta
							if cancel_timer > slap_cancel_window:
								current_shot_state = ShotState.CANCELLED
								slap_charge = 0.0
								slap_charge_percent = 0.0
						else:
							cancel_timer = 0.0
				else:
					current_shot_state = ShotState.CANCELLED
					slap_charge = 0.0
					slap_charge_percent = 0.0
					
			ShotState.RELEASED, ShotState.CANCELLED:
				# RELEASED returns to CARRY only after cooldown and neutral input
				if shot_cooldown_timer <= 0.0 and stick_mag < 0.15:
					current_shot_state = ShotState.CARRY
					
	# Update front marker feedback color (White -> Orange-Red)
	if current_shot_state == ShotState.SLAP_LOADING:
		var load_factor = slap_charge / max_slap_charge_time
		if front_marker_material:
			front_marker_material.albedo_color = Color(1.0, 1.0 - load_factor * 0.8, 1.0 - load_factor)
	else:
		if front_marker_material:
			front_marker_material.albedo_color = Color(1.0, 1.0, 1.0)
			
	# 5. Process Free Puck Physics
	if current_puck_state == PuckState.FREE:
		# Continue existing X/Z movement and friction
		puck_vel = puck_vel.move_toward(Vector3.ZERO, puck_friction * delta)
		puck.translation.x += puck_vel.x * delta
		puck.translation.z += puck_vel.z * delta
		
		# Apply gravity
		puck_vertical_velocity -= puck_gravity * delta
		
		# Update puck height
		puck.translation.y += puck_vertical_velocity * delta
		
		# Ice collision
		if puck.translation.y <= puck_ice_height:
			puck.translation.y = puck_ice_height
			if abs(puck_vertical_velocity) > 2.0:
				puck_vertical_velocity = -puck_vertical_velocity * puck_vertical_bounce
			else:
				puck_vertical_velocity = 0.0
				
		# Puck walls bouncing (rink size is 80x40)
		if abs(puck.translation.x) > 39.0:
			puck.translation.x = sign(puck.translation.x) * 39.0
			puck_vel.x = -puck_vel.x * 0.7
		if abs(puck.translation.z) > 19.0:
			puck.translation.z = sign(puck.translation.z) * 19.0
			puck_vel.z = -puck_vel.z * 0.7
			
	# 6. Update Camera/HUD
	# Camera Smooth Tracking (NHL broadcast-follow camera with damped yaw)
	cam_yaw = lerp_angle(cam_yaw, body_angle, camera_yaw_smooth * delta)
	
	var target_cam_offset = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)) * camera_distance
	var target_cam_pos = player.translation + target_cam_offset + Vector3(0, camera_height, 0)
	camera.translation = camera.translation.linear_interpolate(target_cam_pos, camera_smooth * delta)
	
	current_look_at = current_look_at.linear_interpolate(player.translation, camera_smooth * delta)
	camera.look_at(current_look_at, Vector3.UP)
	
	# Reset Position Action
	if Input.is_action_just_pressed("reset"):
		player.translation = Vector3(0, 1.5, 0)
		puck.translation = Vector3(0, puck_ice_height, 6)
		puck_vel = Vector3.ZERO
		puck_vertical_velocity = 0.0
		current_puck_state = PuckState.FREE
		current_shot_state = ShotState.CARRY
		cam_yaw = body_mesh.rotation.y
		var initial_dir = Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()
		camera.translation = player.translation - initial_dir * camera_distance + Vector3(0, camera_height, 0)
		current_look_at = player.translation
		camera.look_at(current_look_at, Vector3.UP)
		local_x = 0.0
		local_z = base_forward
		blade_target.translation = Vector3(0.0, -1.2, base_forward)
		stick_y_velocity = 0.0
		prev_stick_raw_y = 0.0
		recapture_timer = shot_recapture_delay
		last_shot_type = "NONE"
		last_shot_force = 0.0
		last_shot_lift = 0.0
		last_shot_dir = Vector3.ZERO
		
	# Update HUD display
	var puck_state_str = "FREE" if current_puck_state == PuckState.FREE else "POSSESSED"
	var load_pct = (slap_charge / max_slap_charge_time) * 100.0 if current_shot_state == ShotState.SLAP_LOADING else 0.0
	var state_name := "CARRY"
	match current_shot_state:
		ShotState.CARRY: state_name = "CARRY"
		ShotState.SLAP_LOADING: state_name = "SLAP_LOADING"
		ShotState.RELEASED: state_name = "RELEASED"
		ShotState.CANCELLED: state_name = "CANCELLED"
		
	debug_label.text = (
		"3D Forehand/Backhand Puck Sweep (Basic Shot Elevation)\n" +
		"FPS: %d\n\n" +
		"Debug Info:\n" +
		"  puck_state:          %s\n" +
		"  shot_state:          %s (%d%%)\n" +
		"  did_released_frame:  %s\n" +
		"  puck_vel.length():   %.2f\n" +
		"  puck height:         %.3f\n" +
		"  puck vert velocity:  %.3f\n" +
		"  distance to target:  %.5f\n" +
		"  using_neutral_stick: %s\n" +
		"  control_point_local: (%.2f, %.2f)\n" +
		"  blade_target_global: (%.2f, %.2f, %.2f)\n\n" +
		"Controller Raw Input (Device 0):\n" +
		"  joy_rx (axis 2):     %.2f\n" +
		"  joy_ry (axis 3):     %.2f\n\n" +
		"Shot Settings:\n" +
		"  stick_raw_y:         %.2f\n" +
		"  stick_y_velocity:    %.2f\n" +
		"  shot_cooldown_timer: %.2fs\n" +
		"  last_shot_type:      %s\n" +
		"  last_shot_force:     %.1f\n" +
		"  last_shot_lift:      %.1f\n\n" +
		"Controls:\n" +
		"  Skate (move): WASD / Left Stick (relative to Camera)\n" +
		"  Deke (sweep): Right Stick X (forehand <-> backhand)\n" +
		"  Push/Pull:    Right Stick Y\n" +
		"  Wrist Shot:   Push Forward (<%.2f) OR Space / Circle / Cross\n" +
		"  Slapshot:     Pull Down (>%.2f) to load, then push Up (<%.2f)!\n" +
		"  Reset: R / Start"
	) % [
		fps,
		puck_state_str,
		state_name,
		int(load_pct),
		str(did_release_shot_this_frame),
		puck_vel.length(),
		puck.translation.y,
		puck_vertical_velocity,
		dist_to_target,
		str(using_neutral_stick),
		local_x,
		local_z,
		blade_target.global_transform.origin.x, blade_target.global_transform.origin.y, blade_target.global_transform.origin.z,
		joy_rx,
		joy_ry,
		stick_raw_y,
		stick_y_velocity,
		shot_cooldown_timer,
		last_shot_type,
		last_shot_force,
		last_shot_lift,
		wrist_release_threshold,
		pull_load_threshold,
		flick_release_threshold
	]
	
	# Clear single-frame release trigger at the end of the physics loop
	did_release_shot_this_frame = false
