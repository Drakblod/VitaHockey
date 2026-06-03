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
	var is_perspective = GameManager.current_view_mode != GameManager.ViewMode.TOP_DOWN
	
	var scale_val = 1.0
	var local_offset = Vector2.ZERO
	
	if is_perspective:
		scale_val = GameManager.get_depth_scale(global_position)
		local_offset = GameManager.project_position(global_position) - global_position
		
		# 1. Draw flat shadow first (unrotated, flat Y-scaling)
		draw_set_transform(local_offset, 0.0, Vector2(scale_val, scale_val * 0.4))
		draw_circle(Vector2(0, 15.0), 18.0, Color(0, 0, 0, 0.2))
		
		# 2. Draw body and indicators (unrotated, uniform scale)
		draw_set_transform(local_offset, 0.0, Vector2.ONE * scale_val)
	else:
		# Draw default flat shadow for top-down view (slightly offset)
		draw_circle(Vector2(2, 6), 18.0, Color(0, 0, 0, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Draw pass indicator ring and debug text if active player has possession
	if not is_controlled:
		var main = get_parent()
		var puck_node = get_node_or_null("../Puck")
		var possessing = puck_node and puck_node.state == puck_node.State.POSSESSED and puck_node.player and puck_node.player.is_controlled
		
		if possessing:
			var current_target = main.get_pass_target() if main.has_method("get_pass_target") else null
			var chance = main.get_pass_success_chance(self) if main.has_method("get_pass_success_chance") else 0.0
			var green_thresh = main.pass_success_green_threshold if ("pass_success_green_threshold" in main) else 80.0
			
			var ring_color = Color("#ef4444") # Red (outside cone / no valid target)
			
			var stick_dir = Vector2.RIGHT.rotated(puck_node.player.stick_angle)
			var to_teammate = global_position - puck_node.player.global_position
			var dot = stick_dir.dot(to_teammate.normalized()) if to_teammate.length() > 0.0 else 0.0
			
			if dot >= 0.55:
				if current_target == self and chance > green_thresh:
					ring_color = Color("#22c55e") # Green (success > green_thresh)
				else:
					ring_color = Color("#eab308") # Yellow (in cone)
					
			# Draw indicator ring
			draw_arc(Vector2.ZERO, 28.0, 0, TAU, 24, ring_color, 3.0, true)
			
			# Draw pass chance text above teammate in debug mode
			var is_debug = main.debug_ui_visible if ("debug_ui_visible" in main) else false
			if is_debug:
				var font = main.debug_label.get_font("font") if ("debug_label" in main and main.debug_label) else null
				if font:
					var text = "Pass: %d%%" % int(round(chance))
					if dot < 0.55:
						text = "Pass: 0% (Aim)"
					var text_size = font.get_string_size(text)
					var text_pos = Vector2(-text_size.x / 2.0, -35.0)
					draw_string(font, text_pos, text, ring_color)
					
				# Draw reception zone outline/fill if this teammate is the active pass target
				if current_target == self:
					var rec_rad = puck_node.reception_radius if ("reception_radius" in puck_node) else 65.0
					draw_circle(Vector2.ZERO, rec_rad, Color(0.96, 0.25, 0.37, 0.1))
					draw_arc(Vector2.ZERO, rec_rad, 0, TAU, 32, Color(0.96, 0.25, 0.37, 0.3), 1.0, true)
				
	# Draw player body
	draw_circle(Vector2.ZERO, 20.0, Color("#3b82f6")) # Blue team player
	
	# Determine drawing vectors (convert world vectors to screen vectors in BROADCAST_VIEW)
	var draw_facing = facing_dir
	var draw_stick_angle = stick_angle
	if GameManager.current_view_mode == GameManager.ViewMode.BROADCAST_VIEW:
		draw_facing = Vector2(facing_dir.y, -facing_dir.x)
		var world_stick_dir = Vector2.RIGHT.rotated(stick_angle)
		var screen_stick_dir = Vector2(world_stick_dir.y, -world_stick_dir.x)
		draw_stick_angle = screen_stick_dir.angle()
	
	# Draw player facing direction
	draw_line(Vector2.ZERO, draw_facing * 20.0, Color("#ffffff"), 3.0)
	
	# Draw hockey stick
	var stick_color = Color("#d97706") # Dark Amber/Wooden
	var local_stick_target = Vector2.RIGHT.rotated(draw_stick_angle) * visual_stick_length
	draw_line(Vector2.ZERO, local_stick_target, stick_color, 4.0)
	
	# Draw stick blade
	var blade_perp = Vector2.RIGHT.rotated(draw_stick_angle + PI/2) * 10.0
	draw_line(local_stick_target - blade_perp * 0.5, local_stick_target + blade_perp * 0.5, stick_color, 6.0)
