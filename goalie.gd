extends KinematicBody2D

export var speed := 140.0
export var crease_top := -50.0
export var crease_bottom := 50.0
export var goal_x := 720.0
export(NodePath) var puck_path

var velocity := Vector2.ZERO
var facing_dir := Vector2.LEFT

onready var puck = get_node_or_null(puck_path) as KinematicBody2D

func _ready():
	# Align goalie to the goal crease position
	global_position.x = goal_x

func _physics_process(delta):
	# Keep X locked at the goal line crease
	global_position.x = goal_x
	
	if not puck:
		return
		
	# Target the puck's Y position, clamped to crease limits
	var target_y = clamp(puck.global_position.y, crease_top, crease_bottom)
	var diff_y = target_y - global_position.y
	
	if abs(diff_y) > 4.0:
		velocity.y = sign(diff_y) * speed
		velocity = move_and_slide(velocity)
		# Clamp coordinate after movement to guarantee vertical boundary limits
		global_position.y = clamp(global_position.y, crease_top, crease_bottom)
	else:
		velocity = Vector2.ZERO
		
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
		
		# 2. Draw body (unrotated, uniform scale)
		draw_set_transform(local_offset, 0.0, Vector2.ONE * scale_val)
	else:
		# Draw default flat shadow for top-down view (slightly offset)
		draw_circle(Vector2(2, 6), 18.0, Color(0, 0, 0, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Goalie body (Vibrant Green)
	draw_circle(Vector2.ZERO, 20.0, Color("#22c55e"))
	
	if GameManager.current_view_mode == GameManager.ViewMode.BROADCAST_VIEW:
		# Visor points DOWN (0, 20)
		draw_line(Vector2.ZERO, Vector2.DOWN * 20.0, Color("#ffffff"), 3.0)
		# Pads are horizontal bar at bottom (Y = 10, X from -18 to 18)
		draw_line(Vector2(-18, 10), Vector2(18, 10), Color("#15803d"), 8.0)
	else:
		# Pads (Dark green bar facing player side)
		draw_line(Vector2(-10, -18), Vector2(-10, 18), Color("#15803d"), 8.0)
		# Face visor
		draw_line(Vector2.ZERO, Vector2.LEFT * 20.0, Color("#ffffff"), 3.0)
