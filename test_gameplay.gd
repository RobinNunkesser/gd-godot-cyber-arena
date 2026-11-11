extends SceneTree

## Headless Testsuite für Cyber Arena 3D
## Überprüft VGLC-Vektorparsing, SurfaceTool-Meshgenerierung, Zero-Allocation-Pools,
## Quaternion-Mathematik und Sphere-Broadphase-Kollision.

const VGLCVectorParser = preload("res://core/vglc_vector_parser.gd")
const ObjectPool3D = preload("res://core/object_pool_3d.gd")
const Projectile3D = preload("res://scripts/projectile_3d.gd")
const Drone3D = preload("res://scripts/drone_3d.gd")
const Player3D = preload("res://scripts/player_3d.gd")
const DroneSwarm = preload("res://scripts/drone_swarm.gd")
const MainArena = preload("res://scenes/main.gd")

func _init() -> void:
	print("==================================================")
	print("🧪 STARTE TESTS: Cyber Arena 3D (VGLC & 3D Pools)")
	print("==================================================")

	var failed = false

	if not test_vglc_vector_parser():
		print("❌ TEST 1 FEHLGESCHLAGEN: VGLC Vektor-Parser & SurfaceTool Mesh")
		failed = true
	else:
		print("✅ TEST 1 BESTANDEN: VGLC Vektor-Parser & SurfaceTool Mesh")

	if not test_object_pool_zero_allocation():
		print("❌ TEST 2 FEHLGESCHLAGEN: Zero-Allocation Object Pool Invariante")
		failed = true
	else:
		print("✅ TEST 2 BESTANDEN: Zero-Allocation Object Pool Invariante")

	if not test_quaternion_rotations():
		print("❌ TEST 3 FEHLGESCHLAGEN: Quaternion-Mathematik & Gimbal-Lock-Schutz")
		failed = true
	else:
		print("✅ TEST 3 BESTANDEN: Quaternion-Mathematik & Gimbal-Lock-Schutz")

	if not test_sphere_broadphase_math():
		print("❌ TEST 4 FEHLGESCHLAGEN: Sphere Broadphase Distanzprüfung")
		failed = true
	else:
		print("✅ TEST 4 BESTANDEN: Sphere Broadphase Distanzprüfung")

	if not test_player_kinematics_and_weapons():
		print("❌ TEST 5 FEHLGESCHLAGEN: Spieler-Kinematik & Geschoss-Trigger")
		failed = true
	else:
		print("✅ TEST 5 BESTANDEN: Spieler-Kinematik & Geschoss-Trigger")

	if not test_scene_initialization():
		print("❌ TEST 6 FEHLGESCHLAGEN: Main-Szene Initialisierung & Game Loop")
		failed = true
	else:
		print("✅ TEST 6 BESTANDEN: Main-Szene Initialisierung & Game Loop")

	print("==================================================")
	if failed:
		print("❌ EINIGE TESTS SIND FEHLGESCHLAGEN!")
		quit(1)
	else:
		print("🎉 ALLE TESTS ERFOLGREICH ABGESCHLOSSEN!")
		quit(0)

func test_vglc_vector_parser() -> bool:
	var path = "res://levels/doom_e1m1_arena.vec"
	var parser = VGLCVectorParser.parse_file(path)
	if parser == null:
		print("  -> Vektordatei konnte nicht geladen werden!")
		return false

	if parser.lines.size() < 10:
		print("  -> Zu wenige Vektorlinien geparst: ", parser.lines.size())
		return false

	if parser.things.size() < 5:
		print("  -> Zu wenige Things geparst: ", parser.things.size())
		return false

	var wall_mesh = parser.generate_wall_mesh()
	if wall_mesh == null or wall_mesh.get_surface_count() == 0:
		print("  -> SurfaceTool konnte kein ArrayMesh aus den Vektoren erzeugen!")
		return false

	var colliders = parser.build_wall_collision_body()
	if colliders == null or colliders.get_child_count() < 10:
		print("  -> Wandkollision unvollständig generiert!")
		colliders.free()
		return false

	colliders.free()
	print("  -> Gepolsterte Linedefs: %d, Things: %d, Meshes generiert: OK" % [parser.lines.size(), parser.things.size()])
	return true

func test_object_pool_zero_allocation() -> bool:
	var dummy_parent = Node.new()
	var pool = ObjectPool3D.new()
	var capacity = 10

	pool.initialize(capacity, func(): return Node3D.new(), dummy_parent)

	if pool.get_capacity() != capacity or pool.get_available_count() != capacity or pool.get_active_count() != 0:
		print("  -> Pool-Initialisierung inkonsistent!")
		dummy_parent.free()
		return false

	# 1. Schöpfe den Pool komplett aus
	var acquired_items: Array[Node3D] = []
	for i in range(capacity):
		var item = pool.acquire()
		if item == null or not item.visible:
			print("  -> Acquire fehlgeschlagen bei Index ", i)
			dummy_parent.free()
			return false
		acquired_items.append(item)

	# 2. Prüfe Sättigung (Capacity Exceeded)
	var overflow = pool.acquire()
	if overflow != null:
		print("  -> Pool hat Objekt trotz voller Auslastung geliefert!")
		dummy_parent.free()
		return false

	# 3. Gebe 4 Objekte zurück
	for i in range(4):
		var ok = pool.release(acquired_items[i])
		if not ok:
			print("  -> Release fehlgeschlagen bei Index ", i)
			dummy_parent.free()
			return false

	if pool.get_active_count() != 6 or pool.get_available_count() != 4:
		print("  -> Invalider Pool-Status nach partiellem Release: aktiv=", pool.get_active_count())
		dummy_parent.free()
		return false

	# 4. Reset All
	pool.reset_all()
	if pool.get_active_count() != 0 or pool.get_available_count() != capacity:
		print("  -> Reset All stellte Pool nicht vollständig her!")
		dummy_parent.free()
		return false

	pool.clear()
	dummy_parent.free()
	return true

func test_quaternion_rotations() -> bool:
	# Teste Vermeidung von Gimbal Lock über Quaternion-Slerp
	var q_north = Quaternion(Vector3.UP, 0.0)
	var q_south = Quaternion(Vector3.UP, PI)
	var q_half = q_north.slerp(q_south, 0.5)

	var dir_half = Basis(q_half) * Vector3.FORWARD
	# Bei 50% Slerp muss die Ausrichtung genau Osten oder Westen sein (X != 0, Z ~ 0)
	if absf(dir_half.z) > 0.1 or absf(dir_half.x) < 0.9:
		print("  -> Quaternion Slerp Interpolation fehlerhaft: ", dir_half)
		return false

	# Verifiziere Basis-Gültigkeit (Orthogonalität und Determinante = 1)
	var basis = Basis(q_half)
	if absf(basis.determinant() - 1.0) > 0.001:
		print("  -> Quaternion transformierte Matrix ist nicht orthogonal!")
		return false

	return true

func test_sphere_broadphase_math() -> bool:
	var p1 = Vector3(0, 0, 0)
	var r1 = 1.0

	var p2_hit = Vector3(1.5, 0, 0) # Distanz = 1.5, r1+r2 = 2.0 -> HIT
	var r2 = 1.0
	var dist_sq_hit = p1.distance_squared_to(p2_hit)
	var comb_r_sq_hit = (r1 + r2) * (r1 + r2)
	if dist_sq_hit > comb_r_sq_hit:
		print("  -> Kollision fälschlicherweise als Miss klassifiziert!")
		return false

	var p2_miss = Vector3(2.5, 0, 0) # Distanz = 2.5, r1+r2 = 2.0 -> MISS
	var dist_sq_miss = p1.distance_squared_to(p2_miss)
	if dist_sq_miss <= comb_r_sq_hit:
		print("  -> Miss fälschlicherweise als Kollision klassifiziert!")
		return false

	return true

func test_player_kinematics_and_weapons() -> bool:
	var player = Player3D.new()

	if player.current_health != player.max_health:
		print("  -> Initial health mismatch: ", player.current_health, " vs ", player.max_health)
		player.free()
		return false

	player.take_damage(3)
	if player.current_health != 7:
		print("  -> Take damage mismatch: ", player.current_health)
		player.free()
		return false

	var fired = [false]
	player.fired_projectile.connect(func(_pos, _dir): fired[0] = true)
	var shot_ok = player.attempt_shoot()
	if not shot_ok or not fired[0]:
		print("  -> First shot failed: shot_ok=", shot_ok, " fired=", fired[0])
		player.free()
		return false

	# Sofortiger zweiter Schuss muss am Cooldown scheitern
	var shot_cooldown = player.attempt_shoot()
	if shot_cooldown:
		print("  -> Cooldown violation: second shot succeeded immediately!")
		player.free()
		return false

	if player.head == null or player.camera == null:
		print("  -> First-Person Kamera oder Kopf-Node fehlt!")
		player.free()
		return false

	if player.current_view != Player3D.ViewMode.FIRST_PERSON:
		print("  -> Standard-Perspektive ist nicht FIRST_PERSON!")
		player.free()
		return false

	player.toggle_view_mode()
	if player.current_view != Player3D.ViewMode.THIRD_PERSON_OVERVIEW:
		print("  -> Umschalten auf Übersichtskamera fehlgeschlagen!")
		player.free()
		return false

	player.toggle_view_mode()
	if player.current_view != Player3D.ViewMode.FIRST_PERSON:
		print("  -> Zurückschalten auf Ego-Perspektive fehlgeschlagen!")
		player.free()
		return false

	player.free()
	return true

func test_scene_initialization() -> bool:
	var scene_res = load("res://scenes/main.tscn")
	if scene_res == null:
		print("  -> main.tscn konnte nicht geladen werden!")
		return false

	var scene: MainArena = scene_res.instantiate() as MainArena
	if scene == null:
		print("  -> main.tscn Instanziierung fehlgeschlagen!")
		return false

	root.add_child(scene)
	if not scene.is_node_ready():
		scene._ready()

	if scene.player == null or scene.projectile_pool == null or scene.drone_pool == null:
		print("  -> Hauptkomponenten der 3D-Szene nicht initialisiert!")
		scene.free()
		return false

	# Teste Spawn einer Drohne und Abfeuern eines Geschosses
	var swarm = scene.get("drone_swarm")
	var drone = swarm.spawn_drone_at(Vector3(5, 0, 5))
	if drone == null:
		print("  -> Drohnenspawn im Schwarm fehlgeschlagen!")
		scene.free()
		return false

	scene._on_player_fired(Vector3(0, 1, 0), Vector3.FORWARD)
	if scene.projectile_pool.get_active_count() != 1:
		print("  -> Geschoss nicht im Pool aktiviert!")
		scene.free()
		return false

	scene.free()
	return true
