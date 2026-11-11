class_name Drone3D
extends Node3D

## Drone3D: 3D-Gegnerdrohne aus dem allokationsfreien Pool.
## Verfolgt den Spieler auf der XZ-Ebene mit weicher Drehungs-Interpolation (Slerp).

signal destroyed(drone: Drone3D)

@export var speed: float = 4.2
@export var collision_radius: float = 0.7
@export var max_health: int = 1

var current_health: int = 1
var target_node: Node3D = null
var mesh_instance: MeshInstance3D = null

func _init() -> void:
	mesh_instance = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(1.2, 0.8, 1.2)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.1, 0.2)
	mat.emission_energy_multiplier = 2.0
	prism.material = mat

	mesh_instance.mesh = prism
	# Drehung, damit die Spitze nach vorn zeigt
	mesh_instance.rotation_degrees = Vector3(-90, 0, 0)
	add_child(mesh_instance)

func on_pool_acquire() -> void:
	current_health = max_health

func on_pool_release() -> void:
	target_node = null

func spawn(pos: Vector3, target: Node3D) -> void:
	if is_inside_tree():
		global_position = pos
	else:
		position = pos
	target_node = target
	current_health = max_health

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	if current_health <= 0:
		destroyed.emit(self)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_node):
		return

	var target_pos = target_node.global_position
	var to_target = (target_pos - global_position)
	to_target.y = 0.0 # Auf XZ-Ebene beschränken

	if to_target.length_squared() > 0.01:
		var dir = to_target.normalized()
		global_position += dir * speed * delta

		# Sanfte Ausrichtung via Quaternion
		var target_angle = atan2(dir.x, dir.z)
		var current_quat = global_transform.basis.get_rotation_quaternion()
		var target_quat = Quaternion(Vector3.UP, target_angle)
		var smooth_quat = current_quat.slerp(target_quat, 10.0 * delta)
		global_transform.basis = Basis(smooth_quat)
