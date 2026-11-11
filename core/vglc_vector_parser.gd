class_name VGLCVectorParser
extends RefCounted

## VGLCVectorParser: Parst kontinuierliche 2D-Vektor-Liniensegmente und Things
## (basierend auf dem Doom-Vektorformat nach Summerville et al., 2016).
## Erzeugt prozedurale 3D-Polygon-Meshes (Wände) via SurfaceTool und statische Kollision.

class VectorLine extends RefCounted:
	var start_pos: Vector2
	var end_pos: Vector2
	var floor_height: float = 0.0
	var ceil_height: float = 4.0
	var flag: String = "wall"

	func _init(p_start: Vector2, p_end: Vector2, p_floor: float = 0.0, p_ceil: float = 4.0, p_flag: String = "wall"):
		start_pos = p_start
		end_pos = p_end
		floor_height = p_floor
		ceil_height = p_ceil
		flag = p_flag

class VectorThing extends RefCounted:
	var position: Vector3
	var type: int = 1 # 1: Player Start, 2: Drone Spawner, 3: Powerup/Ammo
	var angle: float = 0.0

	func _init(p_pos: Vector3, p_type: int = 1, p_angle: float = 0.0):
		position = p_pos
		type = p_type
		angle = p_angle

var lines: Array[VectorLine] = []
var things: Array[VectorThing] = []
var player_start_pos: Vector3 = Vector3(0, 0.0, 0)

func clear() -> void:
	lines.clear()
	things.clear()
	player_start_pos = Vector3(0, 0.0, 0)

static func parse_file(path: String) -> RefCounted:
	var parser = new()
	if not FileAccess.file_exists(path):
		push_error("VGLCVectorParser: Datei nicht gefunden: %s" % path)
		return null
	var fa = FileAccess.open(path, FileAccess.READ)
	var content = fa.get_as_text()
	fa.close()
	parser.parse_string(content)
	return parser

func parse_string(content: String) -> void:
	clear()
	var raw_lines = content.split("\n")

	for line_str in raw_lines:
		var line = line_str.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("//"):
			continue

		var tokens = line.split(" ", false)
		if tokens.size() == 0:
			continue

		var cmd = tokens[0].to_upper()
		if cmd == "LINE" and tokens.size() >= 7:
			var x1 = float(tokens[1])
			var y1 = float(tokens[2])
			var x2 = float(tokens[3])
			var y2 = float(tokens[4])
			var fh = float(tokens[5])
			var ch = float(tokens[6])
			var flag = tokens[7] if tokens.size() > 7 else "wall"
			lines.append(VectorLine.new(Vector2(x1, y1), Vector2(x2, y2), fh, ch, flag))
		elif cmd == "THING" and tokens.size() >= 5:
			var tx = float(tokens[1])
			var ty = float(tokens[2]) # In 3D: Z-Achse
			var tz = float(tokens[3]) # In 3D: Y-Achse (Höhe)
			var ttype = int(tokens[4])
			var tangle = float(tokens[5]) if tokens.size() > 5 else 0.0

			var pos_3d = Vector3(tx, tz, ty)
			var thing = VectorThing.new(pos_3d, ttype, tangle)
			things.append(thing)
			if ttype == 1:
				player_start_pos = pos_3d

## Generiert aus den Liniensegmenten ein kontinuierliches 3D-ArrayMesh via SurfaceTool
func generate_wall_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for l: VectorLine in lines:
		# 2D -> 3D Koordinatentransformation (X=x, Y=Höhe, Z=y)
		var v0 = Vector3(l.start_pos.x, l.floor_height, l.start_pos.y)
		var v1 = Vector3(l.end_pos.x, l.floor_height, l.end_pos.y)
		var v2 = Vector3(l.end_pos.x, l.ceil_height, l.end_pos.y)
		var v3 = Vector3(l.start_pos.x, l.ceil_height, l.start_pos.y)

		# Normale senkrecht zur Wandfläche berechnen
		var wall_dir = (v1 - v0).normalized()
		var wall_normal = Vector3(-wall_dir.z, 0, wall_dir.x) # Orthogonal auf XZ-Ebene

		# Dreieck 1 (v0, v1, v2)
		st.set_normal(wall_normal)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v0)

		st.set_normal(wall_normal)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(v1)

		st.set_normal(wall_normal)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v2)

		# Dreieck 2 (v0, v2, v3)
		st.set_normal(wall_normal)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v0)

		st.set_normal(wall_normal)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v2)

		st.set_normal(wall_normal)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(v3)

		# Rückseite Dreieck 1 (v1, v0, v3)
		var back_normal = -wall_normal
		st.set_normal(back_normal)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(v1)

		st.set_normal(back_normal)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v0)

		st.set_normal(back_normal)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(v3)

		# Rückseite Dreieck 2 (v1, v3, v2)
		st.set_normal(back_normal)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(v1)

		st.set_normal(back_normal)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(v3)

		st.set_normal(back_normal)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v2)

	return st.commit()

## Berechnet die Bounding Box der 2D-Vektorlinien [min_p, max_p]
func get_bounds() -> Array[Vector2]:
	if lines.is_empty():
		return [Vector2(-20, -20), Vector2(20, 20)]
	var min_p = lines[0].start_pos
	var max_p = lines[0].start_pos
	for l in lines:
		min_p.x = minf(min_p.x, minf(l.start_pos.x, l.end_pos.x))
		min_p.y = minf(min_p.y, minf(l.start_pos.y, l.end_pos.y))
		max_p.x = maxf(max_p.x, maxf(l.start_pos.x, l.end_pos.x))
		max_p.y = maxf(max_p.y, maxf(l.start_pos.y, l.end_pos.y))
	return [min_p, max_p]

## Erzeugt einen StaticBody3D mit Wand-Kollisionsformen für die Physik
func build_wall_collision_body() -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 1 # Layer 1: Umwelt / Wände
	body.collision_mask = 0

	for l: VectorLine in lines:
		var p1 = Vector3(l.start_pos.x, l.floor_height, l.start_pos.y)
		var p2 = Vector3(l.end_pos.x, l.floor_height, l.end_pos.y)
		var height = l.ceil_height - l.floor_height

		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		var len = p1.distance_to(p2)
		var wall_thickness = 0.4
		box.size = Vector3(len, height, wall_thickness)
		shape.shape = box

		# Position und Drehung der Wand-Box
		var center = (p1 + p2) * 0.5 + Vector3(0, height * 0.5, 0)
		shape.position = center
		var dir = (p2 - p1).normalized()
		var angle_y = atan2(dir.x, dir.z)
		shape.rotation.y = angle_y - PI * 0.5

		body.add_child(shape)

	return body
