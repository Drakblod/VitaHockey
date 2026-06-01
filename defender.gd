extends KinematicBody2D

export var speed := 130.0
export var poke_range := 45.0
export var poke_cooldown_time := 1.2
export var reaction_delay := 0.15 # AI reaction lag time in seconds
export(NodePath) var puck_path

var velocity := Vector2.ZERO
var facing_dir := Vector2.LEFT
var poke_cooldown := 0.0

# Visual poke stick drawing
var _draw_poke_timer := 0.0
var _poke_visual_target := Vector2.ZERO

# Reaction delay buffer history
var _puck_history := []

onready var puck = get_node_or_null(puck_path) as KinematicBody2D

func _physics_process(delta):
	# Decrement cooldowns
	if poke_cooldown > 0.0:
		poke_cooldown -= delta
	if _draw_poke_timer > 0.0:
		_draw_poke_timer -= delta

	if not puck:
		return

	# Record real-time puck coordinates in history
	var current_time = OS.get_ticks_msec() / 1000.0
	_puck_history.append({"pos": puck.global_position, "time": current_time})
	
	# Trim ancient history
	var cut_off = current_time - 1.2
	while _puck_history.size() > 0 and _puck_history[0]["time"] < cut_off:
		_puck_history.remove(0)

	# Fetch delayed target position (reaction lag)
	var target_pos = puck.global_position # Default fallback
	var target_time = current_time - reaction_delay
	for record in _puck_history:
		if record["time"] >= target_time:
			target_pos = record["pos"]
			break

	var to_target = target_pos - global_position
	var dist_to_actual_puck = (puck.global_position - global_position).length()

	# 1. AI Movement: Chase the DELAYED target position
	if to_target.length() > 20.0:
		var target_vel = to_target.normalized() * speed
		velocity = velocity.linear_interpolate(target_vel, 0.1)
		facing_dir = velocity.normalized()
		velocity = move_and_slide(velocity)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)

	# 2. Poke Check Logic (using REAL puck distance)
	var current_poke_range = poke_range
	if puck.state == puck.State.POSSESSED and puck.current_deke == "PULL_BACK":
		current_poke_range = poke_range - 20.0
		
	if dist_to_actual_puck < current_poke_range and poke_cooldown <= 0.0:
		_execute_poke_check()

	update()

func _execute_poke_check():
	poke_cooldown = poke_cooldown_time
	_draw_poke_timer = 0.15
	_poke_visual_target = puck.global_position

	if puck:
		if puck.state == puck.State.POSSESSED:
			# Call centralized release function
			puck.force_release("POKE_CHECK")
			puck.shoot_cooldown = 0.4
			
		var push_dir = (facing_dir + Vector2(rand_range(-0.2, 0.2), rand_range(-0.2, 0.2))).normalized()
		puck.velocity = push_dir * 450.0

func _draw():
	# Draw defender body (Red team opponent)
	draw_circle(Vector2.ZERO, 20.0, Color("#ef4444"))
	
	# Draw facing direction
	draw_line(Vector2.ZERO, facing_dir * 20.0, Color("#ffffff"), 3.0)
	
	# Draw stick
	var stick_color = Color("#b45309")
	var stick_target := Vector2.ZERO
	
	if _draw_poke_timer > 0.0:
		stick_target = _poke_visual_target - global_position
	else:
		var stick_dir = facing_dir
		if puck:
			stick_dir = (puck.global_position - global_position).normalized()
		stick_target = stick_dir * 38.0
		
	draw_line(Vector2.ZERO, stick_target, stick_color, 4.0)
	
	var blade_perp = stick_target.normalized().rotated(PI/2) * 8.0
	draw_line(stick_target - blade_perp, stick_target + blade_perp, stick_color, 5.0)
