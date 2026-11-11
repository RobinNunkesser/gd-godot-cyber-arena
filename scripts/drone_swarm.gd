class_name DroneSwarm
extends Node3D

const ObjectPool3D = preload("res://core/object_pool_3d.gd")
const Projectile3D = preload("res://scripts/projectile_3d.gd")
const Drone3D = preload("res://scripts/drone_3d.gd")
const Player3D = preload("res://scripts/player_3d.gd")

## DroneSwarm: Verwaltet die Drohnenschwärme und führt die allokationsfreie
## Broadphase-Kollisionsprüfung (Sphere Distance Checks) durch.

signal drone_killed(pos: Vector3)
signal wave_cleared()

var drone_pool: ObjectPool3D = null
var projectile_pool: ObjectPool3D = null
var player: Player3D = null
var spawner_positions: Array[Vector3] = []

var active_drones: Array[Drone3D] = []
var active_projectiles: Array[Projectile3D] = []

var spawn_timer: float = 0.0
var spawn_interval: float = 1.8
var current_wave: int = 1
var kills_count: int = 0
var broadphase_checks_last_frame: int = 0

func setup(p_drone_pool: ObjectPool3D, p_proj_pool: ObjectPool3D, p_player: Player3D, spawners: Array[Vector3]) -> void:
	drone_pool = p_drone_pool
	projectile_pool = p_proj_pool
	player = p_player
	spawner_positions = spawners
	active_drones.clear()
	active_projectiles.clear()

func spawn_drone_at(pos: Vector3) -> Drone3D:
	var drone: Drone3D = drone_pool.acquire() as Drone3D
	if drone:
		drone.spawn(pos, player)
		if not active_drones.has(drone):
			active_drones.append(drone)
		if not drone.destroyed.is_connected(_on_drone_destroyed):
			drone.destroyed.connect(_on_drone_destroyed)
	return drone

func register_projectile(proj: Projectile3D) -> void:
	if proj and not active_projectiles.has(proj):
		active_projectiles.append(proj)
		if not proj.expired.is_connected(_on_projectile_expired):
			proj.expired.connect(_on_projectile_expired)

func _physics_process(delta: float) -> void:
	if player == null or player.current_health <= 0:
		return

	# 1. Automatischer Wellen-Spawn
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_next_batch()

	# 2. Broadphase Kollisionsprüfung (Sphere-Sphere Distance Check)
	_perform_broadphase_collision()

func _spawn_next_batch() -> void:
	if spawner_positions.is_empty():
		return
	var count = mini(2, drone_pool.get_available_count())
	for i in range(count):
		var sp_pos = spawner_positions[randi() % spawner_positions.size()]
		var offset = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		spawn_drone_at(sp_pos + offset)

func _perform_broadphase_collision() -> void:
	broadphase_checks_last_frame = 0

	# A. Projektil <-> Drohne Kollision
	var p_idx = active_projectiles.size() - 1
	while p_idx >= 0:
		var proj = active_projectiles[p_idx]
		var proj_pos = proj.global_position
		var proj_r = proj.collision_radius
		var hit = false

		var d_idx = active_drones.size() - 1
		while d_idx >= 0:
			var drone = active_drones[d_idx]
			broadphase_checks_last_frame += 1

			var drone_pos = drone.global_position
			var combined_r = proj_r + drone.collision_radius
			var dist_sq = proj_pos.distance_squared_to(drone_pos)

			# Mathematischer Kugeldistanz-Ausschluss O(1)
			if dist_sq <= combined_r * combined_r:
				drone.take_damage(1)
				_recycle_projectile(proj)
				hit = true
				break
			d_idx -= 1

		if not hit:
			p_idx -= 1
		else:
			p_idx = mini(p_idx - 1, active_projectiles.size() - 1)

	# B. Drohne <-> Spieler Kollision
	if is_instance_valid(player):
		var player_pos = player.global_position
		var player_r = player.collision_radius

		for drone in active_drones:
			broadphase_checks_last_frame += 1
			var combined_r = player_r + drone.collision_radius
			if player_pos.distance_squared_to(drone.global_position) <= combined_r * combined_r:
				player.take_damage(1)
				# Rückstoß für Drohne
				var push_dir = (drone.global_position - player_pos).normalized()
				drone.global_position += push_dir * 1.5

func _on_drone_destroyed(drone: Drone3D) -> void:
	kills_count += 1
	drone_killed.emit(drone.global_position)
	active_drones.erase(drone)
	drone_pool.release(drone)

func _on_projectile_expired(proj: Projectile3D) -> void:
	_recycle_projectile(proj)

func _recycle_projectile(proj: Projectile3D) -> void:
	active_projectiles.erase(proj)
	projectile_pool.release(proj)

func reset_all() -> void:
	active_drones.clear()
	active_projectiles.clear()
	drone_pool.reset_all()
	projectile_pool.reset_all()
	kills_count = 0
	spawn_timer = 0.0
