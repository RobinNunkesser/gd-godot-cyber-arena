class_name Projectile3D
extends Node3D

## Projectile3D: Schnelles 3D-Plasma-Projektil aus dem allokationsfreien Pool.

signal expired(projectile: Projectile3D)

@export var speed: float = 35.0
@export var max_lifetime: float = 2.0
@export var collision_radius: float = 0.3

var velocity: Vector3 = Vector3.ZERO
var current_lifetime: float = 0.0
var mesh_instance: MeshInstance3D = null

func _init() -> void:
	# Einfache Visualisierung: Strahlende Kugel
	mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = collision_radius
	sphere.height = collision_radius * 2.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	sphere.material = mat

	mesh_instance.mesh = sphere
	add_child(mesh_instance)

func on_pool_acquire() -> void:
	current_lifetime = 0.0

func on_pool_release() -> void:
	velocity = Vector3.ZERO
	current_lifetime = 0.0

func fire(from_pos: Vector3, direction: Vector3) -> void:
	if is_inside_tree():
		global_position = from_pos
	else:
		position = from_pos
	velocity = direction.normalized() * speed
	current_lifetime = 0.0

func _physics_process(delta: float) -> void:
	current_lifetime += delta
	if current_lifetime >= max_lifetime:
		expired.emit(self)
		return

	global_position += velocity * delta
