extends KinematicBody2D

export var max_speed := 350.0
export var acceleration := 900.0
export var friction := 500.0

# MVP 6: Visual stick separation
export var visual_stick_length := 55.0

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

func apply_sprint_burst(amount: float):
	velocity += facing_dir * amount

func scale_speed(factor: float):
	speed_scale = factor

func _physics_process(delta):
	speed_scale = move_toward(speed_scale, 1.0, 0.7 * delta)

	# 1. Skating Movement
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
	
	# 2. Stick Aiming Direction & Smoothing
	var stick_dir = GameManager.get_stick_input(global_position)
	if stick_dir.length() == 0.0:
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
