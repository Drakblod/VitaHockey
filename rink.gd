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
	draw_rect(Rect2(-width/2, -height/2, width, height), ice_color)
	
	# 2. Rink Borders (Boards)
	var board_color = Color("#1e293b") # Slate gray/blue
	var board_thickness = 8.0
	draw_line(Vector2(-width/2, -height/2), Vector2(width/2, -height/2), board_color, board_thickness)
	draw_line(Vector2(-width/2, height/2), Vector2(width/2, height/2), board_color, board_thickness)
	draw_line(Vector2(-width/2, -height/2), Vector2(-width/2, height/2), board_color, board_thickness)
	draw_line(Vector2(width/2, -height/2), Vector2(width/2, height/2), board_color, board_thickness)

	# 3. Ice Markings
	var red_line_color = Color("#ef4444")
	var blue_line_color = Color("#3b82f6")
	var line_thickness = 4.0
	
	# Center Red Line
	draw_line(Vector2(0, -height/2), Vector2(0, height/2), red_line_color, line_thickness)
	
	# Blue Lines
	var blue_offset = width * 0.18
	draw_line(Vector2(-blue_offset, -height/2), Vector2(-blue_offset, height/2), blue_line_color, line_thickness + 2.0)
	draw_line(Vector2(blue_offset, -height/2), Vector2(blue_offset, height/2), blue_line_color, line_thickness + 2.0)
	
	# Center Faceoff Circle
	var center_circle_radius = 80.0
	draw_arc(Vector2.ZERO, center_circle_radius, 0, TAU, 64, red_line_color, line_thickness, true)
	draw_circle(Vector2.ZERO, 6.0, red_line_color)
	
	# Faceoff Dots
	var dot_x = width * 0.35
	var dot_y = height * 0.25
	draw_circle(Vector2(-dot_x, -dot_y), 5.0, red_line_color)
	draw_circle(Vector2(-dot_x, dot_y), 5.0, red_line_color)
	draw_circle(Vector2(dot_x, -dot_y), 5.0, red_line_color)
	draw_circle(Vector2(dot_x, dot_y), 5.0, red_line_color)
	
	# Goal Creases
	var crease_radius = 45.0
	draw_arc(Vector2(-width/2 + 50.0, 0), crease_radius, -PI/2, PI/2, 32, blue_line_color, line_thickness - 1.0, true)
	draw_arc(Vector2(width/2 - 50.0, 0), crease_radius, PI/2, 3*PI/2, 32, blue_line_color, line_thickness - 1.0, true)
	
	# Goals (Simple rectangle outlines)
	var goal_width = 35.0
	var goal_height = 80.0
	# Left Goal (Red outline)
	draw_rect(Rect2(-width/2 + 15.0, -goal_height/2, goal_width, goal_height), Color("#ef4444"), false, 3.0)
	# Right Goal (Red outline)
	draw_rect(Rect2(width/2 - 50.0, -goal_height/2, goal_width, goal_height), Color("#ef4444"), false, 3.0)
