extends StaticBody2D

signal goal_scored(scoring_team)

export var width := 1600.0
export var height := 800.0

func _ready():
	# Connect goal detectors programmatically to avoid complex editor wiring in .tscn
	var left_detector = get_node_or_null("LeftGoalDetector")
	var right_detector = get_node_or_null("RightGoalDetector")
	
	if left_detector:
		left_detector.connect("body_entered", self, "_on_left_goal_body_entered")
	if right_detector:
		right_detector.connect("body_entered", self, "_on_right_goal_body_entered")
		
	update()

func _on_left_goal_body_entered(body):
	if body.name == "Puck":
		# Puck entered left goal, meaning the RIGHT team (or opponent) scored
		emit_signal("goal_scored", "opponent")

func _on_right_goal_body_entered(body):
	if body.name == "Puck":
		# Puck entered right goal, meaning the LEFT team (player) scored
		emit_signal("goal_scored", "player")

func _draw():
	# 1. Ice Background
	var ice_color = Color("#f0f8ff") # Alice Blue
	if GameManager.current_view_mode != GameManager.ViewMode.TOP_DOWN:
		# Draw projected ice as a trapezoid polygon
		var corners = PoolVector2Array([
			GameManager.project_position(Vector2(-width/2, -height/2)),
			GameManager.project_position(Vector2(width/2, -height/2)),
			GameManager.project_position(Vector2(width/2, height/2)),
			GameManager.project_position(Vector2(-width/2, height/2))
		])
		draw_polygon(corners, PoolColorArray([ice_color]))
	else:
		draw_rect(Rect2(-width/2, -height/2, width, height), ice_color)
	
	# 2. Rink Borders (Boards)
	var board_color = Color("#1e293b") # Slate gray/blue
	var board_thickness = 8.0
	if GameManager.current_view_mode != GameManager.ViewMode.TOP_DOWN:
		var board_corners = PoolVector2Array([
			GameManager.project_position(Vector2(-width/2, -height/2)),
			GameManager.project_position(Vector2(width/2, -height/2)),
			GameManager.project_position(Vector2(width/2, height/2)),
			GameManager.project_position(Vector2(-width/2, height/2)),
			GameManager.project_position(Vector2(-width/2, -height/2))
		])
		draw_polyline(board_corners, board_color, board_thickness, true)
	else:
		draw_line(Vector2(-width/2, -height/2), Vector2(width/2, -height/2), board_color, board_thickness)
		draw_line(Vector2(-width/2, height/2), Vector2(width/2, height/2), board_color, board_thickness)
		draw_line(Vector2(-width/2, -height/2), Vector2(-width/2, height/2), board_color, board_thickness)
		draw_line(Vector2(width/2, -height/2), Vector2(width/2, height/2), board_color, board_thickness)

	# 3. Ice Markings
	var red_line_color = Color("#ef4444")
	var blue_line_color = Color("#3b82f6")
	var line_thickness = 4.0
	
	# Center Red Line
	draw_line(
		GameManager.project_position(Vector2(0, -height/2)), 
		GameManager.project_position(Vector2(0, height/2)), 
		red_line_color, 
		line_thickness
	)
	
	# Blue Lines
	var blue_offset = width * 0.18
	draw_line(
		GameManager.project_position(Vector2(-blue_offset, -height/2)), 
		GameManager.project_position(Vector2(-blue_offset, height/2)), 
		blue_line_color, 
		line_thickness + 2.0
	)
	draw_line(
		GameManager.project_position(Vector2(blue_offset, -height/2)), 
		GameManager.project_position(Vector2(blue_offset, height/2)), 
		blue_line_color, 
		line_thickness + 2.0
	)
	
	# Center Faceoff Circle
	var center_circle_radius = 80.0
	draw_projected_circle(Vector2.ZERO, center_circle_radius, red_line_color, line_thickness)
	draw_circle(
		GameManager.project_position(Vector2.ZERO), 
		6.0 * GameManager.get_depth_scale(Vector2.ZERO), 
		red_line_color
	)
	
	# Faceoff Dots
	var dot_x = width * 0.35
	var dot_y = height * 0.25
	
	var dot_positions = [
		Vector2(-dot_x, -dot_y),
		Vector2(-dot_x, dot_y),
		Vector2(dot_x, -dot_y),
		Vector2(dot_x, dot_y)
	]
	
	for dot_pos in dot_positions:
		draw_circle(
			GameManager.project_position(dot_pos), 
			5.0 * GameManager.get_depth_scale(dot_pos), 
			red_line_color
		)
	
	# Goal Creases
	var crease_radius = 45.0
	draw_projected_arc(Vector2(-width/2 + 50.0, 0), crease_radius, -PI/2, PI/2, blue_line_color, line_thickness - 1.0)
	draw_projected_arc(Vector2(width/2 - 50.0, 0), crease_radius, PI/2, 3*PI/2, blue_line_color, line_thickness - 1.0)
	
	# Goals (Simple rectangle outlines)
	var goal_width = 35.0
	var goal_height = 80.0
	# Left Goal (Red outline)
	draw_projected_rect_outline(Rect2(-width/2 + 15.0, -goal_height/2, goal_width, goal_height), Color("#ef4444"), 3.0)
	# Right Goal (Red outline)
	draw_projected_rect_outline(Rect2(width/2 - 50.0, -goal_height/2, goal_width, goal_height), Color("#ef4444"), 3.0)

func draw_projected_circle(center: Vector2, radius: float, color: Color, thickness: float = 1.0):
	var points = PoolVector2Array()
	var steps = 64
	for i in range(steps + 1):
		var angle = i * TAU / steps
		var p = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(GameManager.project_position(p))
	draw_polyline(points, color, thickness, true)

func draw_projected_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, thickness: float = 1.0):
	var points = PoolVector2Array()
	var steps = 32
	for i in range(steps + 1):
		var angle = lerp(start_angle, end_angle, float(i) / steps)
		var p = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(GameManager.project_position(p))
	draw_polyline(points, color, thickness, true)

func draw_projected_rect_outline(rect: Rect2, color: Color, thickness: float = 1.0):
	var points = PoolVector2Array([
		GameManager.project_position(Vector2(rect.position.x, rect.position.y)),
		GameManager.project_position(Vector2(rect.position.x + rect.size.x, rect.position.y)),
		GameManager.project_position(Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)),
		GameManager.project_position(Vector2(rect.position.x, rect.position.y + rect.size.y)),
		GameManager.project_position(Vector2(rect.position.x, rect.position.y))
	])
	draw_polyline(points, color, thickness, true)
