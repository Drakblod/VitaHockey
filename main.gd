extends Node2D

enum GameState {
	PLAY,
	GOAL_CELEBRATION,
	FACEOFF,
	PERIOD_OVER
}

onready var player = $Player
onready var defender = $Defender
onready var goalie = $Goalie
onready var puck = $Puck
onready var camera = $Camera2D
onready var debug_panel = $CanvasLayer/DebugUI/PanelContainer
onready var debug_label = $CanvasLayer/DebugUI/PanelContainer/MarginContainer/Label
onready var announcement_label = $CanvasLayer/GameUI/AnnouncementLabel
onready var period_timer_label = $CanvasLayer/GameUI/PeriodTimerLabel

var game_state = GameState.FACEOFF
var faceoff_timer := 4.0
var celebration_timer := 0.0
var period_timer := 180.0
var debug_ui_visible := true

var player_score := 0
var opponent_score := 0
var goal_text := ""
var opponent_disabled := false

func _ready():
	# Centered label scaling logic to look premium with standard Godot fonts
	announcement_label.rect_scale = Vector2(3, 3)
	announcement_label.rect_pivot_offset = Vector2(400, 60)
	period_timer_label.rect_scale = Vector2(1.5, 1.5)
	period_timer_label.rect_pivot_offset = Vector2(200, 15)

	var rink = get_node_or_null("Rink")
	if rink:
		rink.connect("goal_scored", self, "_on_rink_goal_scored")
		
	setup_faceoff(true)

func set_active_player(new_player: KinematicBody2D):
	if not new_player:
		return
	player = new_player
	
	# Update control states for all blue team players
	var players = get_tree().get_nodes_in_group("blue_team")
	for p in players:
		p.is_controlled = (p == player)
		if not p.is_controlled:
			p.velocity = Vector2.ZERO

func get_pass_target() -> KinematicBody2D:
	if not puck or puck.state != puck.State.POSSESSED or not player:
		return null
		
	var stick_dir = Vector2.RIGHT.rotated(player.stick_angle)
	var best_target = null
	var best_dot = 0.55 # dot product threshold (approx 56 degrees either side)
	
	var players = get_tree().get_nodes_in_group("blue_team")
	for p in players:
		if p == player:
			continue
			
		var to_teammate = p.global_position - player.global_position
		var dist = to_teammate.length()
		if dist > 0.0:
			var dir = to_teammate / dist
			var dot = stick_dir.dot(dir)
			if dot > best_dot:
				best_dot = dot
				best_target = p
				
	return best_target

func set_entities_frozen(frozen: bool):
	var players = get_tree().get_nodes_in_group("blue_team")
	for p in players:
		p.set_physics_process(not frozen)
		
	if defender and not opponent_disabled:
		defender.set_physics_process(not frozen)
	if goalie:
		goalie.set_physics_process(not frozen)
	puck.set_physics_process(not frozen)

func setup_faceoff(full_reset_timer: bool):
	game_state = GameState.FACEOFF
	faceoff_timer = 4.0
	
	if full_reset_timer:
		period_timer = 180.0
		
	goal_text = ""
	announcement_label.text = ""
	
	# Reset active player control to default $Player
	set_active_player($Player)
	
	# Freeze gameplay nodes physics processing
	set_entities_frozen(true)
	
	# Zero out velocities and reset positions for all blue team players
	var players = get_tree().get_nodes_in_group("blue_team")
	for p in players:
		p.velocity = Vector2.ZERO
		p.facing_dir = Vector2.UP if p == $Player else Vector2.RIGHT
		
	# Teleport player nodes
	$Player.global_position = Vector2(0, 100)
	var teammate = get_node_or_null("Teammate")
	if teammate:
		teammate.global_position = Vector2(250, 100)
		
	if defender:
		defender.velocity = Vector2.ZERO
		defender.facing_dir = Vector2.DOWN
		defender.global_position = Vector2(0, -100)
		
	if goalie:
		goalie.velocity = Vector2.ZERO
		goalie.global_position = Vector2(720, 0)
		
	# Release puck to reset its collision shape and variables
	puck.force_release("NONE")
	puck.velocity = Vector2.ZERO
	puck.shot_charge = 0.0
	puck.shoot_cooldown = 0.5
	puck.global_position = Vector2.ZERO
	
	# Snap camera instantly and reset smoothing
	camera.global_position = player.global_position
	camera.reset_smoothing()

func _process(delta):
	# Camera smoothly tracks player
	if player and game_state != GameState.FACEOFF and game_state != GameState.PERIOD_OVER:
		camera.global_position = player.global_position

	# Handle resets at any time
	if GameManager.is_reset_pressed():
		var reset_timer = (game_state == GameState.PERIOD_OVER)
		if Input.is_key_pressed(KEY_SHIFT):
			player_score = 0
			opponent_score = 0
			reset_timer = true
		setup_faceoff(reset_timer)
		return

	# Handle Debug UI toggle
	if Input.is_action_just_pressed("toggle_debug"):
		debug_ui_visible = not debug_ui_visible
		debug_panel.visible = debug_ui_visible

	# State Machine Processing
	match game_state:
		GameState.FACEOFF:
			faceoff_timer -= delta
			if faceoff_timer > 3.0:
				announcement_label.text = "3"
			elif faceoff_timer > 2.0:
				announcement_label.text = "2"
			elif faceoff_timer > 1.0:
				announcement_label.text = "1"
			elif faceoff_timer > 0.0:
				announcement_label.text = "GO!"
				# Unfreeze entities on GO!
				if not player.is_physics_processing():
					set_entities_frozen(false)
					puck.force_release("NONE")
			else:
				announcement_label.text = ""
				game_state = GameState.PLAY
				
		GameState.PLAY:
			# Toggle Opponent AI (only in PLAY state)
			if GameManager.is_toggle_opponent_pressed():
				opponent_disabled = not opponent_disabled
				if defender:
					var is_active = not opponent_disabled
					defender.visible = is_active
					defender.set_physics_process(is_active)
					if is_active:
						defender.collision_layer = 1
						defender.collision_mask = 1
					else:
						defender.collision_layer = 0
						defender.collision_mask = 0
						
			# Period timer countdown
			period_timer = max(period_timer - delta, 0.0)
			if period_timer <= 0.0:
				game_state = GameState.PERIOD_OVER
				set_entities_frozen(true)
				puck.force_release("NONE")
				announcement_label.text = "PERIOD OVER"
				
			# Manual goal scoring check for carried possessed puck
			if puck and puck.state == puck.State.POSSESSED:
				var puck_x = puck.global_position.x
				var puck_y = puck.global_position.y
				if abs(puck_y) < 40.0:
					if puck_x > 750.0:
						_on_rink_goal_scored("player")
					elif puck_x < -750.0:
						_on_rink_goal_scored("opponent")
						
		GameState.GOAL_CELEBRATION:
			celebration_timer -= delta
			if celebration_timer <= 0.0:
				setup_faceoff(false)
				
		GameState.PERIOD_OVER:
			pass

	# Update Period Timer HUD
	var minutes = int(period_timer) / 60
	var seconds = int(period_timer) % 60
	period_timer_label.text = "Period 1 - %02d:%02d" % [minutes, seconds]

	# Update Debug UI Panel
	if debug_label and debug_ui_visible and player and puck:
		var fps = Engine.get_frames_per_second()
		var player_speed = player.velocity.length()
		var stick_angle_deg = rad2deg(player.stick_angle)
		var puck_state_str = "POSSESSED" if puck.state == puck.State.POSSESSED else "FREE"
		var puck_speed = puck.velocity.length()
		
		var time_possessed = puck.time_possessed if puck.state == puck.State.POSSESSED else 0.0
		var stick_ang_vel = puck.stick_angular_velocity if puck.state == puck.State.POSSESSED else 0.0
		var turn_sharpness = player.turn_sharpness
		var loss_reason = puck.possession_loss_reason
		var turn_loss_status = "ENABLED" if puck.enable_sharp_turn_loss else "DISABLED"
		var active_deke = puck.current_deke
		
		var stick_target_to_puck_dist = puck.possessed_target_distance if puck.state == puck.State.POSSESSED else 0.0
		var desired_target_dist = puck.desired_target_distance if puck.state == puck.State.POSSESSED else 0.0
		var smoothed_target_dist = puck.smoothed_target_distance if puck.state == puck.State.POSSESSED else 0.0
		
		var raw_stick_angle_deg = rad2deg(player.raw_stick_angle)
		var smoothed_stick_angle_deg = rad2deg(player.stick_angle)
		var stick_angle_delta_val = player.stick_angle_delta
		
		var puck_ctrl_dist = puck.puck_control_distance
		var visual_stk_len = player.visual_stick_length
		
		var charge_str = "READY"
		if puck.state == puck.State.POSSESSED and puck.shot_charge > 0.0:
			var charge_pct = puck.shot_charge * 100.0
			var bar_length = 8
			var filled = int(round(puck.shot_charge * bar_length))
			var bar = ""
			for i in range(bar_length):
				if i < filled:
					bar += "█"
				else:
					bar += "░"
			charge_str = "[%s] %.0f%%" % [bar, charge_pct]
			
		var opponent_ai_str = "DISABLED" if opponent_disabled else "ACTIVE"
		var score_str = "SCORE: Player %d | Opponent %d" % [player_score, opponent_score]
		
		var ctrl_player_str = player.name if player else "NONE"
		var pass_target_node = get_pass_target()
		var pass_target_str = pass_target_node.name if pass_target_node else "NONE"
		
		# Count controlled players
		var controlled_count = 0
		var blue_players = get_tree().get_nodes_in_group("blue_team")
		for bp in blue_players:
			if bp.is_controlled:
				controlled_count += 1
		
		debug_label.text = (
			"%s\n" +
			"FPS: %d\n" +
			"Player Speed: %.1f px/s\n" +
			"Stick Angle: %.1f°\n" +
			"Puck State: %s\n" +
			"Puck Speed: %.1f px/s\n\n" +
			"Possession Stats:\n" +
			"  Time Possessed: %.2f s\n" +
			"  Stick Ang Velocity: %.1f°/s\n" +
			"  Turn Sharpness: %.2f\n" +
			"  Turn Loss Logic: %s\n" +
			"  Current Deke: %s\n" +
			"  Last Loss Reason: %s\n" +
			"  Stick Target to Puck Dist: %.1f px\n" +
			"  Desired Target Dist: %.1f px\n" +
			"  Smoothed Target Dist: %.1f px\n" +
			"  Puck Control Distance: %.1f px\n" +
			"  Visual Stick Length: %.1f px\n" +
			"  Raw Stick Angle: %.1f°\n" +
			"  Smoothed Stick Angle: %.1f°\n" +
			"  Stick Angle Delta: %.1f°/s\n" +
			"  Active Player: %s\n" +
			"  Pass Target: %s\n" +
			"  Number of Controlled Players: %d\n" +
			"  Opponent AI: %s\n" +
			"  Shot Charge: %s\n\n" +
			"Controls:\n" +
			"  Skate: WASD / Left Stick\n" +
			"  Stick Handling: Arrows / Mouse / Right Stick\n" +
			"  Shoot: Hold/Release Space or Click\n" +
			"  Pass: C Key / Square (X) / L1\n" +
			"  Sprint/Deke Touch: Shift / R1\n" +
			"  Toggle Opponent: O / Select\n" +
			"  Reset (Soft): R | Reset (Full): Shift+R\n" +
			"  Toggle Debug Window: K"
		) % [
			score_str, fps, player_speed, stick_angle_deg, puck_state_str, puck_speed,
			time_possessed, stick_ang_vel, turn_sharpness, turn_loss_status, active_deke, loss_reason,
			stick_target_to_puck_dist, desired_target_dist, smoothed_target_dist,
			puck_ctrl_dist, visual_stk_len,
			raw_stick_angle_deg, smoothed_stick_angle_deg, stick_angle_delta_val,
			ctrl_player_str, pass_target_str, controlled_count, opponent_ai_str, charge_str
		]

func _on_rink_goal_scored(scoring_team):
	if game_state == GameState.GOAL_CELEBRATION or game_state == GameState.FACEOFF or game_state == GameState.PERIOD_OVER:
		return
		
	# Freeze gameplay nodes physics processing
	set_entities_frozen(true)
	
	# Increment score
	if scoring_team == "player":
		player_score += 1
		goal_text = "PLAYER GOAL!!!"
	else:
		opponent_score += 1
		goal_text = "OPPONENT GOAL!!!"
		
	# Release puck to reset its collision shape and variables
	puck.force_release("NONE")
	puck.velocity = Vector2.ZERO
	puck.shot_charge = 0.0
	
	# Transition to goal celebration state
	game_state = GameState.GOAL_CELEBRATION
	celebration_timer = 1.5
	announcement_label.text = goal_text
