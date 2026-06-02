extends KinematicBody2D

enum State {
	FREE,
	POSSESSED
}

export(NodePath) var player_path
export var friction := 180.0          # Ice friction (sliding deceleration)
export var bounce_coeff := 0.75       # Wall bounce speed multiplier
export var capture_radius := 35.0     # Radius to grab the puck

# Tuned variables for Arcade stability
export var possession_break_distance := 130.0
export var possession_grace_time := 0.5
export var stick_turn_loss_threshold := 260.0 # Degrees per second
export var enable_sharp_turn_loss := false
export var possession_follow_speed := 16.0

# Shooting/Passing variables
export var wrist_shot_force := 550.0
export var slap_shot_force := 950.0
export var pass_force := 480.0
export var max_charge_time := 0.8

# MVP 4: Skill Stick Deke variables
export var deke_cooldown_time := 0.25
export var lateral_deke_force := 55.0
export var push_ahead_force := 80.0
export var push_ahead_speed_boost := 180.0

# MVP 5 & 6: Target Smoothing, Clamping, and Leash exports
export var target_smoothing_speed := 30.0
export var max_possessed_puck_speed := 1200.0
export var leash_distance := 65.0
export var target_max_speed := 1200.0

# Refinement: Separate control distance from visual stick length
export var puck_control_distance := 45.0
export var min_puck_control_distance := 38.0
export var max_puck_control_distance := 55.0

var state = State.FREE
var velocity := Vector2.ZERO
var shoot_cooldown := 0.0

# Shooting charge metric
var shot_charge := 0.0

# Deke state tracking variables
var current_deke := "NONE"
var deke_timer := 0.0
var deke_cooldown := 0.0
var deke_offset := Vector2.ZERO

# Possession target smoothing variables
var smoothed_possessed_target := Vector2.ZERO
var _last_desired_target := Vector2.ZERO

# Debug & Tuning metrics
var time_possessed := 0.0
var stick_angular_velocity := 0.0
var possession_loss_reason := "NONE"

# Debug distances
var possessed_target_distance := 0.0
var desired_target_distance := 0.0
var smoothed_target_distance := 0.0

var _last_stick_angle := 0.0

var last_pass_target: KinematicBody2D = null
var time_free := 0.0

onready var player = get_node_or_null(player_path) as KinematicBody2D

func _physics_process(delta):
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
		
	match state:
		State.FREE:
			_process_free(delta)
		State.POSSESSED:
			_process_possessed(delta)
			
	update()

func _process_free(delta):
	time_free += delta
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.normal) * bounce_coeff
		move_and_collide(velocity.slide(collision.normal) * delta)
		
	if shoot_cooldown <= 0.0:
		var players = get_tree().get_nodes_in_group("blue_team")
		for p in players:
			var dist_to_stick = global_position.distance_to(p.stick_target_pos)
			var can_capture = false
			if p.is_controlled:
				can_capture = (dist_to_stick < capture_radius)
			else:
				var is_last_pass_target = (p == last_pass_target)
				var is_very_close = (dist_to_stick < capture_radius * 0.7)
				can_capture = (is_last_pass_target and dist_to_stick < capture_radius) or (time_free >= 0.25 and is_very_close)
				
			if can_capture:
				_capture_puck(p)
				break

func _process_possessed(delta):
	if not player:
		state = State.FREE
		return
		
	time_possessed += delta
	
	# Update deke cooldowns
	if deke_cooldown > 0.0:
		deke_cooldown -= delta
	if deke_timer > 0.0:
		deke_timer -= delta
		if deke_timer <= 0.0:
			if current_deke in ["LATERAL_LEFT", "LATERAL_RIGHT", "PUSH_AHEAD"]:
				current_deke = "NONE"
				deke_offset = Vector2.ZERO
	
	# Calculate stick angular velocity
	var current_stick_angle = player.stick_angle
	var angle_diff = _short_angle_diff(_last_stick_angle, current_stick_angle)
	stick_angular_velocity = rad2deg(abs(angle_diff)) / delta
	_last_stick_angle = current_stick_angle
	
	# Deke triggers
	var stick_dir = Vector2.RIGHT.rotated(player.stick_angle)
	
	if deke_timer <= 0.0:
		# A) Push-Ahead Touch
		if GameManager.is_sprint_tapped() and deke_cooldown <= 0.0:
			if stick_dir.dot(player.facing_dir) > 0.6:
				current_deke = "PUSH_AHEAD"
				deke_timer = 0.40
				deke_cooldown = deke_cooldown_time
				deke_offset = player.facing_dir * push_ahead_force
				player.apply_sprint_burst(push_ahead_speed_boost)
				
		# B) Quick Lateral Deke
		elif deke_cooldown <= 0.0 and stick_angular_velocity > 280.0:
			var perp_dot = stick_dir.dot(player.facing_dir.rotated(PI/2))
			if abs(perp_dot) > 0.7:
				var deke_right = perp_dot > 0.0
				current_deke = "LATERAL_RIGHT" if deke_right else "LATERAL_LEFT"
				deke_timer = 0.35
				deke_cooldown = deke_cooldown_time
				deke_offset = player.facing_dir.rotated(PI/2) * (lateral_deke_force if deke_right else -lateral_deke_force)
				player.scale_speed(0.85)
				
		# C) Pull-Back Deke (Passive)
		elif stick_dir.dot(player.facing_dir) < -0.5 and not (player.velocity.dot(stick_dir) < -50.0 and stick_dir.x > 0.1):
			current_deke = "PULL_BACK"
			deke_offset = Vector2.ZERO
		else:
			if current_deke == "PULL_BACK":
				current_deke = "NONE"
				
	# Calculate desired target incorporating deke offsets and sharp turn damping
	var active_deke_offset = deke_offset
	if player.turn_sharpness > 0.1:
		var turn_scale = clamp(1.0 - player.turn_sharpness * 0.4, 0.5, 1.0)
		active_deke_offset *= turn_scale
		
	# Determine min and max control distances
	var min_dist = min_puck_control_distance
	var max_dist = max_puck_control_distance
	
	if current_deke == "PULL_BACK":
		min_dist = 25.0
		max_dist = 25.0
	elif current_deke == "PUSH_AHEAD":
		max_dist = 105.0
		
	var desired_target = Vector2.ZERO
	if current_deke == "NONE":
		# Normal possession: stick direction comes strictly from player.stick_angle, constant visual stick length and puck distance
		desired_target = player.global_position + stick_dir * puck_control_distance
		player.visual_stick_length = 55.0
	else:
		# Dekes active (PULL_BACK, PUSH_AHEAD, LATERAL_LEFT, LATERAL_RIGHT)
		var desired_distance = puck_control_distance
		if current_deke == "PULL_BACK":
			desired_distance = 25.0
			
		# Clamp base distance first
		desired_distance = clamp(desired_distance, min_dist, max_dist)
		
		# Form the base target
		desired_target = player.global_position + stick_dir * desired_distance
		if current_deke != "PULL_BACK":
			desired_target += active_deke_offset
			
		# Clamp final desired target distance from player
		var to_desired = desired_target - player.global_position
		var distance = to_desired.length()
		var direction = to_desired.normalized() if distance > 0.0 else Vector2.ZERO
		
		var clamped_distance = clamp(distance, min_dist, max_dist)
		desired_target = player.global_position + direction * clamped_distance
		
		# Shorten or lengthen visual stick length accordingly during dekes
		player.visual_stick_length = clamped_distance + 8.0
	
	# Smooth stick target path using direct position move_toward logic
	smoothed_possessed_target = smoothed_possessed_target.move_toward(desired_target, target_max_speed * delta)
	
	var to_target = smoothed_possessed_target - global_position
	var dist_to_stick = to_target.length()
	
	# 1. Break possession if puck gets too far from stick target (Distance check)
	var break_dist = possession_break_distance
	if current_deke == "PUSH_AHEAD":
		break_dist = 180.0
		
	if dist_to_stick > break_dist:
		_release_puck("DISTANCE")
		shot_charge = 0.0
		return
		
	# Absolute player safety check with recovery snapping
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > 180.0:
		global_position = smoothed_possessed_target
		dist_to_player = global_position.distance_to(player.global_position)
		if dist_to_player > 180.0:
			_release_puck("BAD_POSSESSED_DISTANCE")
			shot_charge = 0.0
			return
		
	# 2. Break possession on sharp turns (Optional check)
	if enable_sharp_turn_loss and time_possessed > possession_grace_time:
		var player_speed = player.velocity.length()
		if player_speed > player.max_control_speed:
			if stick_angular_velocity > stick_turn_loss_threshold and player.turn_sharpness > player.sharp_turn_loss_factor:
				_release_puck("SHARP_TURN")
				shoot_cooldown = 0.45
				velocity = player.velocity * 1.1
				shot_charge = 0.0
				return
				
	# 3. Check for passing
	if GameManager.is_pass_pressed():
		_pass_puck()
		return
		
	# 4. Check for shooting
	if GameManager.is_shoot_held():
		shot_charge = min(shot_charge + delta / max_charge_time, 1.0)
	elif GameManager.is_shoot_released() or shot_charge > 0.0:
		_shoot(shot_charge)
		return
		
	# Position-controlled puck movement (using direct step)
	if current_deke != "PUSH_AHEAD" and to_target.length() > 45.0:
		global_position = global_position.move_toward(smoothed_possessed_target, 2500.0 * delta)
	else:
		global_position = global_position.move_toward(smoothed_possessed_target, max_possessed_puck_speed * delta)
	velocity = Vector2.ZERO
 
	# 5. Hard stick-blade leash constraint (applied only while possessed)
	var current_leash = leash_distance
	if current_deke == "PUSH_AHEAD":
		current_leash = 120.0
		
	var to_puck_clamped = global_position - smoothed_possessed_target
	if to_puck_clamped.length() > current_leash:
		global_position = smoothed_possessed_target + to_puck_clamped.clamped(current_leash)
		
	# Ensure puck doesn't end up inside/beside player during rapid movement/lag
	var to_puck = global_position - player.global_position
	var puck_dist = to_puck.length()
	if puck_dist < min_dist:
		var puck_dir = to_puck.normalized() if puck_dist > 0.0 else stick_dir
		global_position = player.global_position + puck_dir * min_dist
 
	# Store debug distances for main.gd HUD renderer
	possessed_target_distance = global_position.distance_to(smoothed_possessed_target)
	desired_target_distance = player.global_position.distance_to(desired_target)
	smoothed_target_distance = player.global_position.distance_to(smoothed_possessed_target)

# --- Centralized Capture / Release Helpers ---

func _capture_puck(p: KinematicBody2D):
	player = p
	state = State.POSSESSED
	time_possessed = 0.0
	_last_stick_angle = player.stick_angle
	stick_angular_velocity = 0.0
	shot_charge = 0.0
	current_deke = "NONE"
	deke_timer = 0.0
	deke_offset = Vector2.ZERO
	smoothed_possessed_target = player.stick_target_pos
	_last_desired_target = player.stick_target_pos
	velocity = Vector2.ZERO
	
	var main = get_parent()
	if main and main.has_method("set_active_player"):
		main.set_active_player(p)
		
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape:
		col_shape.set_deferred("disabled", true)

func _release_puck(reason: String):
	state = State.FREE
	possession_loss_reason = reason
	current_deke = "NONE"
	deke_offset = Vector2.ZERO
	time_free = 0.0
	
	if reason == "PASS":
		var main = get_parent()
		if main and main.has_method("get_pass_target"):
			last_pass_target = main.get_pass_target()
		else:
			last_pass_target = null
	else:
		last_pass_target = null
		
	if player:
		player.visual_stick_length = 55.0
		
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape:
		col_shape.set_deferred("disabled", false)

func force_release(reason: String):
	if state == State.POSSESSED:
		_release_puck(reason)
		shot_charge = 0.0

func _shoot(charge_amount: float):
	_release_puck("SHOT")
	shoot_cooldown = 0.25
	var shoot_dir = Vector2.RIGHT.rotated(player.stick_angle)
	var force = lerp(wrist_shot_force, slap_shot_force, charge_amount)
	velocity = player.velocity + shoot_dir * force
	shot_charge = 0.0

func _pass_puck():
	_release_puck("PASS")
	shoot_cooldown = 0.25
	
	var stick_dir = Vector2.RIGHT.rotated(player.stick_angle)
	var pass_dir = stick_dir
	if last_pass_target:
		var dir_to_teammate = (last_pass_target.global_position - player.global_position).normalized()
		pass_dir = stick_dir.lerp(dir_to_teammate, 0.85).normalized()
		
	velocity = player.velocity + pass_dir * pass_force
	shot_charge = 0.0

func _short_angle_diff(from: float, to: float) -> float:
	var diff = to - from
	while diff < -PI:
		diff += TAU
	while diff > PI:
		diff -= TAU
	return diff

func _draw():
	draw_circle(Vector2(2, 2), 7.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, 7.0, Color("#0f172a"))
	draw_circle(Vector2.ZERO, 5.0, Color("#1e293b"))
	if state == State.POSSESSED:
		draw_arc(Vector2.ZERO, 11.0, 0, TAU, 16, Color("#38bdf8"), 2.0, true)
