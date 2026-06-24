extends Spatial

onready var camera = $Camera
onready var cube = $TestCube
onready var imm_geom = $ImmediateGeometry
onready var debug_label = $UI/DebugLabel

func _ready():
	# Explicitly make camera current
	camera.make_current()
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	# Draw a large ImmediateGeometry green triangle at the XZ plane
	var mat = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true
	imm_geom.set_material_override(mat)
	
	imm_geom.clear()
	imm_geom.begin(Mesh.PRIMITIVE_TRIANGLES)
	imm_geom.set_color(Color(0, 1, 0, 1)) # Green
	imm_geom.add_vertex(Vector3(-10, 0, -10))
	imm_geom.add_vertex(Vector3(10, 0, -10))
	imm_geom.add_vertex(Vector3(0, 0, 10))
	imm_geom.end()

func _physics_process(delta):
	# Keep camera centered on the origin
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	# Rotate the test cube slightly to verify movement
	cube.rotate_y(0.5 * delta)
	cube.rotate_x(0.2 * delta)
	
	var fps = Engine.get_frames_per_second()
	
	# Diagnostics info
	var root_class = self.get_class()
	var cam_current = camera.current
	var cam_pos = camera.global_transform.origin
	var cube_pos = cube.global_transform.origin
	var view_size = get_viewport().size
	
	# ProjectSettings details
	var driver = ProjectSettings.get_setting("rendering/quality/driver/driver_name")
	var fb_alloc = ProjectSettings.get_setting("rendering/quality/intended_usage/framebuffer_allocation")
	var fb_alloc_mobile = ProjectSettings.get_setting("rendering/quality/intended_usage/framebuffer_allocation.mobile")
	
	debug_label.text = (
		"3D Feasibility Test (Depth Calibration)\n" +
		"FPS: %d\n" +
		"Root Node Type: %s\n" +
		"Camera Current: %s\n" +
		"Camera Pos: (%.1f, %.1f, %.1f)\n" +
		"Viewport Size: %d x %d\n\n" +
		"Render Configuration:\n" +
		"  Driver: %s\n" +
		"  Framebuffer Alloc: %s\n" +
		"  Framebuffer Alloc (Mobile): %s\n\n" +
		"Cube Pos: (%.1f, %.1f, %.1f)\n" +
		"Cube Visible: %s"
	) % [
		fps,
		root_class,
		str(cam_current),
		cam_pos.x, cam_pos.y, cam_pos.z,
		view_size.x, view_size.y,
		str(driver),
		str(fb_alloc),
		str(fb_alloc_mobile),
		cube_pos.x, cube_pos.y, cube_pos.z,
		str(cube.visible)
	]
