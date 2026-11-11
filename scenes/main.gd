class_name MainArena
extends Node3D

## MainArena: 3D Cyber Arena Hauptszene
## Demonstriert VGLC-Vektor-Extrusion, allokationsfreie 3D-Pools und Quaternion-Kinematik.

const VGLCVectorParser = preload("res://core/vglc_vector_parser.gd")
const ObjectPool3D = preload("res://core/object_pool_3d.gd")
const Projectile3D = preload("res://scripts/projectile_3d.gd")
const Drone3D = preload("res://scripts/drone_3d.gd")
const Player3D = preload("res://scripts/player_3d.gd")
const DroneSwarm = preload("res://scripts/drone_swarm.gd")

@export var level_path: String = "res://levels/doom_e1m1_arena.vec"
@export var projectile_pool_size: int = 50
@export var drone_pool_size: int = 25

# Container
var arena_container: Node3D = null
var pool_container: Node3D = null

# Komponenten
var vector_parser: VGLCVectorParser = null
var projectile_pool: ObjectPool3D = null
var drone_pool: ObjectPool3D = null
var player: Player3D = null
var drone_swarm: DroneSwarm = null
var camera: Camera3D = null

# HUD
var hud_layer: CanvasLayer = null
var stats_label: Label = null
var game_over_panel: Panel = null

func _ready() -> void:
	_setup_world_containers()
	_setup_lighting_and_environment()
	_load_vector_arena()
	_setup_object_pools()
	_setup_player()
	_setup_camera()
	_setup_swarm()
	_setup_hud()

func _setup_world_containers() -> void:
	arena_container = Node3D.new()
	arena_container.name = "ArenaContainer"
	add_child(arena_container)

	pool_container = Node3D.new()
	pool_container.name = "PoolContainer"
	add_child(pool_container)

func _setup_lighting_and_environment() -> void:
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-55, 35, 0)
	dir_light.light_energy = 1.0
	dir_light.light_color = Color(0.9, 0.95, 1.0)
	dir_light.shadow_enabled = true
	add_child(dir_light)

	var env = WorldEnvironment.new()
	var sky_env = Environment.new()
	sky_env.background_mode = Environment.BG_COLOR
	sky_env.background_color = Color(0.04, 0.06, 0.1)
	sky_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky_env.ambient_light_color = Color(0.12, 0.15, 0.22)
	env.environment = sky_env
	add_child(env)

func _load_vector_arena() -> void:
	vector_parser = VGLCVectorParser.parse_file(level_path)
	if vector_parser == null:
		push_error("Fehler beim Laden der VGLC-Vektordatei!")
		return

	# 1. 3D-Boden generieren (44m x 44m)
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(44.0, 44.0)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.1, 0.14)
	floor_mat.roughness = 0.8
	floor_mesh.material = floor_mat

	var floor_instance = MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	arena_container.add_child(floor_instance)

	# 2. Extrudierte 3D-Wände aus VGLC-Linedefs
	var wall_mesh = vector_parser.generate_wall_mesh()
	var wall_instance = MeshInstance3D.new()
	wall_instance.mesh = wall_mesh

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.18, 0.22, 0.3)
	wall_mat.emission_enabled = true
	wall_mat.emission = Color(0.1, 0.4, 0.7)
	wall_mat.emission_energy_multiplier = 0.5
	wall_instance.material_override = wall_mat
	arena_container.add_child(wall_instance)

	# 3. Wand-Kollisionskörper
	var wall_colliders = vector_parser.build_wall_collision_body()
	arena_container.add_child(wall_colliders)

func _setup_object_pools() -> void:
	projectile_pool = ObjectPool3D.new()
	projectile_pool.initialize(projectile_pool_size, func(): return Projectile3D.new(), pool_container)

	drone_pool = ObjectPool3D.new()
	drone_pool.initialize(drone_pool_size, func(): return Drone3D.new(), pool_container)

func _setup_player() -> void:
	player = Player3D.new()
	add_child(player)
	player.position = vector_parser.player_start_pos
	player.fired_projectile.connect(_on_player_fired)
	player.died.connect(_on_player_died)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	var cam_pos = player.position + Vector3(0, 24.0, 16.0)
	if camera.is_inside_tree():
		camera.look_at_from_position(cam_pos, player.position, Vector3.UP)
	else:
		camera.position = cam_pos

func _setup_swarm() -> void:
	var spawners: Array[Vector3] = []
	for t in vector_parser.things:
		if t.type == 2:
			spawners.append(t.position)

	drone_swarm = DroneSwarm.new()
	drone_swarm.setup(drone_pool, projectile_pool, player, spawners)
	add_child(drone_swarm)

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1240, 70)
	panel.position = Vector2(20, 15)
	hud_layer.add_child(panel)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(stats_label)

	# Game Over Banner
	game_over_panel = Panel.new()
	game_over_panel.custom_minimum_size = Vector2(400, 160)
	game_over_panel.position = Vector2(440, 280)
	game_over_panel.visible = false

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 15)
	game_over_panel.add_child(vbox)

	var title = Label.new()
	title.text = "SYSTEM COMPROMISED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Drücke [R] für einen Systemneustart."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	hud_layer.add_child(game_over_panel)

func _on_player_fired(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	var proj: Projectile3D = projectile_pool.acquire() as Projectile3D
	if proj:
		proj.fire(spawn_pos, shoot_dir)
		drone_swarm.register_projectile(proj)

func _on_player_died() -> void:
	game_over_panel.visible = true

func _process(_delta: float) -> void:
	_update_camera_tracking()
	_update_mouse_aiming()
	_update_hud_stats()

func _update_camera_tracking() -> void:
	if is_instance_valid(player) and is_instance_valid(camera):
		var target_pos = player.global_position + Vector3(0, 24.0, 16.0)
		camera.global_position = camera.global_position.lerp(target_pos, 0.1)

func _update_mouse_aiming() -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera) or player.current_health <= 0:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	# Schnittpunkt mit XZ-Ebene (Y=0)
	var ground_plane = Plane(Vector3.UP, 0.0)
	var intersection = ground_plane.intersects_ray(ray_origin, ray_dir)
	if intersection != null:
		player.aim_at_point(intersection)

func _update_hud_stats() -> void:
	if stats_label == null:
		return

	var fps = Engine.get_frames_per_second()
	var p_act = projectile_pool.get_active_count() if projectile_pool else 0
	var p_cap = projectile_pool.get_capacity() if projectile_pool else 0
	var d_act = drone_pool.get_active_count() if drone_pool else 0
	var d_cap = drone_pool.get_capacity() if drone_pool else 0
	var checks = drone_swarm.broadphase_checks_last_frame if drone_swarm else 0
	var kills = drone_swarm.kills_count if drone_swarm else 0
	var hp = player.current_health if player else 0

	stats_label.text = "Cyber Arena 3D | FPS: %d | HP: %d/10 | Kills: %d\nPools: Geschosse %d/%d | Drohnen %d/%d | Sphere-Broadphase Prüfungen/Frame: %d | [WASD/Pfeile] Bewegen | [Klick/Space] Feuer | [R] Reset" % [
		fps, hp, kills, p_act, p_cap, d_act, d_cap, checks
	]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart_arena()

func _restart_arena() -> void:
	game_over_panel.visible = false
	if drone_swarm:
		drone_swarm.reset_all()
	if player:
		player.global_position = vector_parser.player_start_pos
		player.current_health = player.max_health
