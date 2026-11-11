class_name ObjectPool3D
extends RefCounted

## ObjectPool3D: Generischer, allokationsfreier 3D-Objekt-Pool für Godot 4.
## Eliminiert Garbage-Collection-Ruckler und verhindert GPU-Memory-Leaks,
## indem alle Entitäten (Projektile, Drohnen, Partikel) vorinstanziiert werden.

var _pool: Array[Node3D] = []
var _available_indices: Array[int] = []
var _active_count: int = 0
var max_capacity: int = 0

## Initialisiert den Pool mit vorinstanziierten Objekten
func initialize(capacity: int, factory_callable: Callable, parent_node: Node) -> void:
	clear()
	max_capacity = capacity
	_pool.resize(capacity)
	_available_indices.resize(capacity)

	for i in range(capacity):
		var obj: Node3D = factory_callable.call()
		obj.set_process(false)
		obj.set_physics_process(false)
		obj.visible = false
		if obj is CollisionObject3D:
			obj.set_collision_layer_value(1, false)
			obj.set_collision_mask_value(1, false)

		parent_node.add_child(obj)
		_pool[i] = obj
		_available_indices[i] = i

	_active_count = 0

## Holt ein inaktives Objekt aus dem Pool (ohne Speicherallokation)
func acquire() -> Node3D:
	if _available_indices.is_empty():
		return null # Pool ist erschöpft (Sättigungsschutz)

	var idx = _available_indices.pop_back()
	var obj = _pool[idx]
	_active_count += 1

	obj.visible = true
	obj.set_process(true)
	obj.set_physics_process(true)

	if obj.has_method("on_pool_acquire"):
		obj.on_pool_acquire()

	return obj

## Gibt ein aktives Objekt zurück in den Pool
func release(obj: Node3D) -> bool:
	var idx = _pool.find(obj)
	if idx == -1:
		return false # Gehört nicht zu diesem Pool

	if _available_indices.has(idx):
		return false # Bereits zurückgegeben

	if obj.has_method("on_pool_release"):
		obj.on_pool_release()

	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)

	_available_indices.append(idx)
	_active_count = maxi(0, _active_count - 1)
	return true

## Setzt alle Objekte des Pools auf inaktiv zurück
func reset_all() -> void:
	_available_indices.clear()
	for i in range(_pool.size()):
		var obj = _pool[i]
		if obj.has_method("on_pool_release"):
			obj.on_pool_release()
		obj.visible = false
		obj.set_process(false)
		obj.set_physics_process(false)
		_available_indices.append(i)
	_active_count = 0

func get_active_count() -> int:
	return _active_count

func get_available_count() -> int:
	return _available_indices.size()

func get_capacity() -> int:
	return max_capacity

func clear() -> void:
	for obj in _pool:
		if is_instance_valid(obj):
			obj.queue_free()
	_pool.clear()
	_available_indices.clear()
	_active_count = 0
	max_capacity = 0

