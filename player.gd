extends KinematicBody2D

export var max_speed := 350.0
export var acceleration := 900.0
export var friction := 500.0

# MVP 6: Visual stick separation
export var visual_stick_length := 55.0
export var is_controlled := true
export var ai_support_speed := 120.0

# MVP 2: Possession loss variables (Tuned)
export var max_control_speed := 420.0
export var sharp_turn_loss_factor := 0.25

# MVP 6: Stick smoothing variables
export var stick_smoothing_speed := 14.0
export var max_stick_rotation_speed := 540.0

var velocity := Vector2.ZERO
var facing_dir := Vector2.RIGHT
var stick_angle := 0.0
var stick_target_pos := Vector2.ZERO
var turn_sharpness := 0.0

# Deke speed scale modifier
var speed_scale := 1.0

# Debug stick angles
var raw_stick_angle := 0.0
var stick_angle_delta := 0.0

func _ready():
	stick_angle = facing_dir.angle()
	add_to_group("blue_team")

func apply_sprint_burst(amount: float):
	velocity += facing_dir * amount

func scale_speed(factor: float):
	speed_scale = factor

func _physics_process(delta):
	speed_scale = move_toward(speed_scale, 1.0, 0.7 * delta)

	# 1. Skating Movement
	if is_controlled:
		var move_dir = GameManager.get_skate_input()
		
		var current_max_speed = max_speed
		if GameManager.is_sprint_held():
			current_max_speed = max_speed * 1.25
			
		var speed = velocity.length()
		if move_dir.length() > 0.0:
			if speed > 10.0:
				var dot = velocity.normalized().dot(move_dir)
				turn_sharpness = 1.0 - dot
			else:
				turn_sharpness = 0.0
				
			velocity += move_dir * acceleration * delta
			velocity = velocity.clamped(current_max_speed * speed_scale)
			facing_dir = move_dir
		else:
			turn_sharpness = 0.0
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			
		velocity = move_and_slide(velocity)
	else:
		turn_sharpness = 0.0
		# Find the controlled puck carrier in the blue team
		var carrier = null
		var players = get_tree().get_nodes_in_group("blue_team")
		for p in players:
			if p.is_controlled:
				carrier = p
				break
				
		var target_position = Vector2(300.0, 0.0)
		if carrier:
			if carrier.global_position.x < 0.0:
				# Carrier in defensive zone, stand in high slot
				target_position = Vector2(250.0, 0.0)
			else:
				# Carrier in offensive zone, skate to slot/one-timer support spot
				if carrier.global_position.y > 0.0:
					target_position = Vector2(450.0, -120.0)
				else:
					target_position = Vector2(450.0, 120.0)
					
			# Repel teammate if too close to puck carrier to prevent crowding
			var to_carrier = global_position - carrier.global_position
			var dist_to_carrier = to_carrier.length()
			if dist_to_carrier < 160.0 and dist_to_carrier > 0.0:
				target_position += to_carrier.normalized() * 120.0
				
		# Stay inside rink boundaries
		target_position.x = clamp(target_position.x, 100.0, 650.0)
		target_position.y = clamp(target_position.y, -300.0, 300.0)
		
		# Simple steering to target position
		var to_target = target_position - global_position
		var dist_to_target = to_target.length()
		
		if dist_to_target < 25.0:
			# Slow down/stop if within 25px of support spot
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		else:
			var desired_velocity = to_target.normalized() * ai_support_speed
			velocity = velocity.move_toward(desired_velocity, acceleration * delta)
			
		velocity = move_and_slide(velocity)
		if velocity.length() > 10.0:
			facing_dir = velocity.normalized()
	
	# 2. Stick Aiming Direction & Smoothing
	var stick_dir = Vector2.ZERO
	if is_controlled:
		stick_dir = GameManager.get_stick_input(global_position)
		if stick_dir.length() == 0.0:
			stick_dir = facing_dir
	else:
		var puck = get_node_or_null("../Puck")
		if puck:
			stick_dir = (puck.global_position - global_position).normalized()
		else:
			stick_dir = facing_dir
		
	raw_stick_angle = stick_dir.angle()
	
	var diff = raw_stick_angle - stick_angle
	while diff < -PI:
		diff += TAU
	while diff > PI:
		diff -= TAU
		
	var change = diff * stick_smoothing_speed * delta
	
	if GameManager.is_mouse_aiming():
		var max_step_rad = deg2rad(max_stick_rotation_speed) * delta
		change = clamp(change, -max_step_rad, max_step_rad)
		
	stick_angle += change
	while stick_angle < -PI:
		stick_angle += TAU
	while stick_angle > PI:
		stick_angle -= TAU
		
	stick_angle_delta = rad2deg(change) / delta
	
	# Visual stick target calculation using visual_stick_length
	var smoothed_stick_dir = Vector2.RIGHT.rotated(stick_angle)
	stick_target_pos = global_position + smoothed_stick_dir * visual_stick_length
	
	update()

func _draw():
	# Draw glowing target ring if this teammate is the active pass target
	if not is_controlled:
		var main = get_parent()
		if main and main.has_method("get_pass_target"):
			if main.get_pass_target() == self:
				draw_arc(Vector2.ZERO, 28.0, 0, TAU, 24, Color("#f43f5e"), 3.0, true) # Rose indicator ring
				
				# Dotted/thin outline and transparent fill of the reception zone in debug mode
				var is_debug = main.debug_ui_visible if ("debug_ui_visible" in main) else false
				if is_debug:
					var puck_node = get_node_or_null("../Puck")
					var rec_rad = puck_node.reception_radius if (puck_node and "reception_radius" in puck_node) else 65.0
					draw_circle(Vector2.ZERO, rec_rad, Color(0.96, 0.25, 0.37, 0.1))
					draw_arc(Vector2.ZERO, rec_rad, 0, TAU, 32, Color(0.96, 0.25, 0.37, 0.3), 1.0, true)
				
	# Draw player body
	draw_circle(Vector2.ZERO, 20.0, Color("#3b82f6")) # Blue team player
	
	# Draw player facing direction
	draw_line(Vector2.ZERO, facing_dir * 20.0, Color("#ffffff"), 3.0)
	
	# Draw hockey stick
	var stick_color = Color("#d97706") # Dark Amber/Wooden
	var local_stick_target = stick_target_pos - global_position
	draw_line(Vector2.ZERO, local_stick_target, stick_color, 4.0)
	
	# Draw stick blade
	var blade_perp = Vector2.RIGHT.rotated(stick_angle + PI/2) * 10.0
	draw_line(local_stick_target - blade_perp * 0.5, local_stick_target + blade_perp * 0.5, stick_color, 6.0)
