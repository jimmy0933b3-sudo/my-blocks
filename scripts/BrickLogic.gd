extends RefCounted
const Catalog = preload("res://scripts/BrickCatalog.gd")
const UNIT := 0.72
const HEIGHT := 0.52
const MAX_PIECES := 350
const MAX_LAYER := 16
const EXTENT := 16

static func part(kind: int, color_index: int, rotation: int, cell: Vector3i, identifier: int) -> Dictionary:
	return {"id":identifier,"kind":kind,"color":color_index,"rotation":posmod(rotation,4),"x":cell.x,"y":cell.y,"z":cell.z}

static func cell_of(p: Dictionary) -> Vector3i:
	return Vector3i(int(p.get("x",0)),int(p.get("y",0)),int(p.get("z",0)))

static func world_position(p: Dictionary) -> Vector3:
	var c := cell_of(p)
	return Vector3(float(c.x)*UNIT,float(c.y)*HEIGHT,float(c.z)*UNIT)

static func can_place(existing: Array, item: Dictionary, ignore_id: int = -1) -> bool:
	var kind := int(item.get("kind",-1))
	if kind < 0 or kind >= Catalog.count():
		return false
	var size := Catalog.size_for(kind,int(item.get("rotation",0)))
	var c := cell_of(item)
	if c.y < 0 or c.y > MAX_LAYER or c.x < -EXTENT or c.z < -EXTENT:
		return false
	if c.x + size.x > EXTENT or c.z + size.y > EXTENT:
		return false
	if existing.size() >= MAX_PIECES and ignore_id == -1:
		return false
	var has_support := c.y == 0
	for other in existing:
		if int(other.get("id",-1)) == ignore_id:
			continue
		var oc := cell_of(other)
		var os := Catalog.size_for(int(other.get("kind",0)),int(other.get("rotation",0)))
		var overlap_x := c.x < oc.x + os.x and oc.x < c.x + size.x
		var overlap_z := c.z < oc.z + os.y and oc.z < c.z + size.y
		if overlap_x and overlap_z:
			if c.y == oc.y:
				return false
			if c.y == oc.y + 1:
				has_support = true
	return has_support

static func has_orphans(existing: Array) -> bool:
	for item in existing:
		if not can_place(existing,item,int(item.get("id",-1))):
			return true
	return false

static func validate_saved_piece(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for k in ["id","kind","color","rotation","x","y","z"]:
		if not value.has(k) or not (value[k] is int or value[k] is float):
			return false
	var c := cell_of(value)
	return int(value["kind"]) >= 0 and int(value["kind"]) < Catalog.count() and c.y >= 0 and c.y <= MAX_LAYER and abs(c.x) <= EXTENT and abs(c.z) <= EXTENT
