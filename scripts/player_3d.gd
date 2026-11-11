class_name Player3D
extends CharacterBody3D

## Player3D: Kinematischer 3D-Spieler-Charakter
## Realisiert 3D-Vektor-Bewegung, Maus-Raycast-Zielen und Quaternion-Ausrichtung.

signal fired_projectile(pos: Vector3, dir: Vector3)
signal health_changed(current: int, max_hp: int)
signal died()

@export var speed: float = 9.0
@export var acceleration: float = 40.0
@export var fire_rate: float = 0.15 # Sekunden zwischen Schüssen
@export var max_health: int = 10
@export var collision_radius: float = 0.8

var current_health: int = 10
var fire_cooldown: float = 0.0
var aim_direction: Vector3 = Vector3.FORWARD
var mesh_instance: MeshInstance3D = null

func _init() -> void:
	current_health = max_health

	# Kapsel-Mesh für den Spieler
	mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.7, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.4, 0.9)
	mat.emission_energy_multiplier = 1.5
	capsule.material = mat

	mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0, 0.8, 0)
	add_child(mesh_instance)

	# Geschütz/Visier-Nase
	var nose = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 0.6)
	var nose_mat = StandardMaterial3D.new()
	nose_mat.albedo_color = Color(1.0, 0.9, 0.2)
	nose.mesh = box
	nose.position = Vector3(0, 1.0, -0.6)
	add_child(nose)

	# Physik-Kollisionsform
	var col_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.6
	col_shape.shape = capsule_shape
	col_shape.position = Vector3(0, 0.8, 0)
	add_child(col_shape)

	collision_layer = 2 # Layer 2: Spieler
	collision_mask = 1  # Mask 1: Wände

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	# 1. Kontinuierliche 3D-Bewegung auf XZ-Ebene
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0

	input_dir = input_dir.normalized()
	var target_vel = input_dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	velocity.y = 0.0 # Flache Arena

	move_and_slide()

	# 2. Ausrichtung via Quaternion
	if input_dir.length_squared() > 0.01:
		aim_direction = input_dir
		var target_angle = atan2(aim_direction.x, aim_direction.z)
		# Basis über Quaternion rotieren (vermeidet Gimbal Lock)
		transform.basis = Basis(Quaternion(Vector3.UP, target_angle + PI))

	# 3. Schießen
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE):
		attempt_shoot()

func aim_at_point(world_point: Vector3) -> void:
	var to_point = world_point - global_position
	to_point.y = 0.0
	if to_point.length_squared() > 0.01:
		aim_direction = to_point.normalized()
		var target_angle = atan2(aim_direction.x, aim_direction.z)
		transform.basis = Basis(Quaternion(Vector3.UP, target_angle + PI))

func attempt_shoot() -> bool:
	if fire_cooldown <= 0.0 and current_health > 0:
		fire_cooldown = fire_rate
		var base_pos = global_position if is_inside_tree() else position
		var spawn_pos = base_pos + Vector3(0, 1.0, 0) + (-transform.basis.z * 0.8)
		var shoot_dir = -transform.basis.z
		fired_projectile.emit(spawn_pos, shoot_dir)
		return true
	return false

func take_damage(amount: int = 1) -> void:
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()
