class_name Player3D
extends CharacterBody3D

## Player3D: Kinematischer Ego-Shooter Charakter (First-Person Controller)
## Realisiert kontinuierliche 3D-Bewegung (WASD & Strafe), Maus-Blickwinkel (Yaw/Pitch)
## und Schießen durch das Fadenkreuz direkt in Blickrichtung.

signal fired_projectile(pos: Vector3, dir: Vector3)
signal health_changed(current: int, max_hp: int)
signal died()
signal perspective_changed(is_first_person: bool)

enum ViewMode {
	FIRST_PERSON,
	THIRD_PERSON_OVERVIEW
}

@export var speed: float = 8.5
@export var acceleration: float = 45.0
@export var fire_rate: float = 0.15
@export var max_health: int = 10
@export var collision_radius: float = 0.6
@export var mouse_sensitivity: float = 0.0025

var current_health: int = 10
var fire_cooldown: float = 0.0
var current_view: ViewMode = ViewMode.FIRST_PERSON

# Kindknoten
var head: Node3D = null
var camera: Camera3D = null
var overhead_camera: Camera3D = null
var mesh_instance: MeshInstance3D = null
var weapon_muzzle: Marker3D = null

func _init() -> void:
	current_health = max_health
	_setup_collision()
	_setup_body_mesh()
	_setup_cameras()

func _setup_collision() -> void:
	collision_layer = 2 # Layer 2: Spieler
	collision_mask = 1  # Mask 1: Wände

	var col_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.7
	col_shape.shape = capsule_shape
	col_shape.position = Vector3(0, 0.85, 0)
	add_child(col_shape)

func _setup_body_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.7

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.7, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.4, 0.9)
	mat.emission_energy_multiplier = 1.5
	capsule.material = mat

	mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0, 0.85, 0)
	add_child(mesh_instance)

func _setup_cameras() -> void:
	# 1. Kopf-Knoten auf Augenhöhe (1.5m)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.5, 0)
	add_child(head)

	# 2. First-Person Kamera (Ego-Perspektive)
	camera = Camera3D.new()
	camera.name = "CameraFirstPerson"
	camera.fov = 75.0
	camera.current = true
	head.add_child(camera)

	# 3. Mündungs-Referenzpunkt (etwas vor der Kamera)
	weapon_muzzle = Marker3D.new()
	weapon_muzzle.name = "Muzzle"
	weapon_muzzle.position = Vector3(0.2, -0.2, -0.6)
	head.add_child(weapon_muzzle)

	# 4. Optionale Third-Person Übersichtskamera (Isometrisch)
	overhead_camera = Camera3D.new()
	overhead_camera.name = "CameraOverhead"
	overhead_camera.fov = 55.0
	overhead_camera.current = false
	overhead_camera.position = Vector3(0, 22.0, 15.0)
	overhead_camera.rotation_degrees = Vector3(-55, 0, 0)
	add_child(overhead_camera)

func _ready() -> void:
	# Im Browser / Desktop Maus fangen für Ego-Steuerung
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_view_visibility()

func _input(event: InputEvent) -> void:
	if current_health <= 0:
		return

	# Maus fangen & lösen
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_V:
			toggle_view_mode()

	# Ego-Kameradrehung über Mausbewegung
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontale Drehung (Yaw) dreht den Spieler-Körper
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertikale Neigung (Pitch) neigt den Kopf (geclampt gegen Überkopf-Rollen)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -deg_to_rad(85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	# Tastatur-Kameradrehung (Pfeiltasten Links/Rechts drehen ebenfalls den Blickwinkel)
	if Input.is_key_pressed(KEY_LEFT):
		rotate_y(2.5 * delta)
	if Input.is_key_pressed(KEY_RIGHT):
		rotate_y(-2.5 * delta)
	if Input.is_key_pressed(KEY_PAGEUP):
		head.rotation.x = clampf(head.rotation.x + 2.0 * delta, -deg_to_rad(85), deg_to_rad(85))
	if Input.is_key_pressed(KEY_PAGEDOWN):
		head.rotation.x = clampf(head.rotation.x - 2.0 * delta, -deg_to_rad(85), deg_to_rad(85))

	# 1. Kontinuierliche Bewegung relativ zur Blickrichtung (WASD & Strafe)
	var input_vector = Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_vector.y += 1.0

	input_vector = input_vector.normalized()

	# Bewegungstransformation in Spieler-Ausrichtung
	var forward = -transform.basis.z
	var right = transform.basis.x
	var move_direction = (forward * (-input_vector.y) + right * input_vector.x).normalized()

	var target_vel = move_direction * speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	velocity.y = 0.0 # Flache Arena

	move_and_slide()

	# 2. Schießen
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE):
		attempt_shoot()

func attempt_shoot() -> bool:
	if fire_cooldown <= 0.0 and current_health > 0:
		fire_cooldown = fire_rate
		var spawn_pos: Vector3
		var shoot_dir: Vector3

		if is_inside_tree() and camera:
			# Schuss exakt durch die Blickachse der Kamera
			shoot_dir = -camera.global_transform.basis.z
			spawn_pos = camera.global_position + shoot_dir * 0.8
		else:
			shoot_dir = -transform.basis.z
			var base_pos = global_position if is_inside_tree() else position
			spawn_pos = base_pos + Vector3(0, 1.5, 0) + shoot_dir * 0.8

		fired_projectile.emit(spawn_pos, shoot_dir)
		return true
	return false

func toggle_view_mode() -> void:
	if current_view == ViewMode.FIRST_PERSON:
		current_view = ViewMode.THIRD_PERSON_OVERVIEW
		camera.current = false
		overhead_camera.current = true
	else:
		current_view = ViewMode.FIRST_PERSON
		overhead_camera.current = false
		camera.current = true

	_update_view_visibility()
	perspective_changed.emit(current_view == ViewMode.FIRST_PERSON)

func _update_view_visibility() -> void:
	# Im First-Person-Modus wird das eigene Mesh ausgeblendet (verhindert Kamera-Clipping)
	if mesh_instance:
		mesh_instance.visible = (current_view == ViewMode.THIRD_PERSON_OVERVIEW)

func take_damage(amount: int = 1) -> void:
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()
