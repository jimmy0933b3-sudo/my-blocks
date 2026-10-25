extends RefCounted
## Pure 2D brick geometry. Coordinates are integer cells for finger-friendly snapping.
const COLUMNS := 18
const ROWS := 9
const MAX_BRICKS := 160
const SHAPES: Array[Vector2i] = [
	Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),
	Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),
	Vector2i(1,2),Vector2i(1,3),Vector2i(1,4),
	Vector2i(2,3),Vector2i(3,3),Vector2i(1,1)
]
# Store original shape IDs for v2 save compatibility, show only one per size.
const PALETTE_KINDS: Array[int] = [0,1,2,3,4,5,10,11]
const COLORS: Array[String] = [
	"#FF6268","#FF9E57","#FFD563","#F7E68A",
	"#93DD75","#4EC7A6","#60CEE0","#66A6FF",
	"#947AF0","#D591EA","#FF9DC8","#F9C5AA",
	"#B84E52","#A76B40","#D4B58B","#FFF3DF",
	"#FFFFFF","#DAE5E9","#A6BCCF","#71839E",
	"#35445C","#3B354A","#CAED84","#2E9D7B",
	"#287BA7","#6750A8","#D86F94","#DBA44B",
	"#7C9850","#F4A1A1","#93D9E9","#BBB0F5"
]

static func canonical_kind(kind: int) -> int:
	match kind:
		6: return 0
		7: return 1
		8: return 2
		9: return 4
		_: return kind

static func canonical_rotation(kind: int) -> int:
	return 1 if kind in [6,7,8,9] else 0

static func size_for(kind: int, rotation: int = 0) -> Vector2i:
	if kind < 0 or kind >= SHAPES.size():
		return Vector2i.ONE
	var dims := SHAPES[kind]
	if posmod(rotation,2) == 1:
		return Vector2i(dims.y,dims.x)
	return dims

static func rotation_of(piece: Dictionary) -> int:
	return posmod(int(piece.get("rotation",0)),2)

static func turned_piece(piece: Dictionary, existing: Array) -> Dictionary:
	# Preserve the center of the brick while snapping to grid.
	var dims := size_for(int(piece["kind"]),rotation_of(piece))
	if dims.x == dims.y:
		return {}
	var target_rotation := 1-rotation_of(piece)
	var after := size_for(int(piece["kind"]),target_rotation)
	var ideal := Vector2(cell_of(piece))+Vector2(dims-after)*0.5
	var options: Array[Vector2i] = [
		Vector2i(floori(ideal.x),floori(ideal.y)),
		Vector2i(ceili(ideal.x),floori(ideal.y)),
		Vector2i(floori(ideal.x),ceili(ideal.y)),
		Vector2i(ceili(ideal.x),ceili(ideal.y))
	]
	options.sort_custom(func(a: Vector2i,b: Vector2i):
		return (Vector2(a)-ideal).length_squared() < (Vector2(b)-ideal).length_squared()
	)
	for pos in options:
		var result := piece.duplicate(true)
		result["rotation"] = target_rotation
		result["x"] = pos.x
		result["y"] = pos.y
		if can_place(existing,result,int(piece["id"])):
			return result
	return {}

static func shape_label(kind: int) -> String:
	var s := size_for(kind)
	return "%d×%d" % [s.x,s.y]

static func color_for(index: int) -> Color:
	return Color.html(COLORS[posmod(index,COLORS.size())])

static func make_piece(id: int, kind: int, color_id: int, pos: Vector2i, rotation: int = 0) -> Dictionary:
	return {"id":id,"kind":kind,"color":color_id,"x":pos.x,"y":pos.y,"rotation":posmod(rotation,2)}

static func cell_of(piece: Dictionary) -> Vector2i:
	return Vector2i(int(piece.get("x",0)),int(piece.get("y",0)))

static func rect_of(piece: Dictionary) -> Rect2i:
	return Rect2i(cell_of(piece),size_for(int(piece["kind"]),rotation_of(piece)))

static func valid_piece(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	for key in ["id","kind","color","x","y"]:
		if not data.has(key) or not (data[key] is int or data[key] is float):
			return false
		if float(data[key]) != float(int(data[key])):
			return false
	# rotation is optional because old 2D save files contain only kind/x/y.
	if data.has("rotation"):
		if not (data["rotation"] is int or data["rotation"] is float):
			return false
		if float(data["rotation"]) != float(int(data["rotation"])) or int(data["rotation"]) not in [0,1]:
			return false
	return int(data["id"]) >= 1 and int(data["kind"]) >= 0 and int(data["kind"]) < SHAPES.size() and int(data["color"]) >= 0 and int(data["color"]) < COLORS.size()

static func can_place(existing: Array, item: Dictionary, ignoring_id: int = -1) -> bool:
	if not valid_piece(item):
		return false
	var rect := rect_of(item)
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > COLUMNS or rect.end.y > ROWS:
		return false
	if existing.size() >= MAX_BRICKS and ignoring_id == -1:
		return false
	for other in existing:
		if int(other.get("id",-1)) == ignoring_id:
			continue
		if rect.intersects(rect_of(other)):
			return false
	return true

static func document_valid(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if int(data.get("version",-1)) != 2 or not (data.get("pieces",null) is Array):
		return false
	var parts: Array = data["pieces"]
	if parts.size() > MAX_BRICKS:
		return false
	var visited: Dictionary = {}
	var placed: Array = []
	for piece in parts:
		if not valid_piece(piece):
			return false
		if visited.has(piece["id"]) or not can_place(placed,piece):
			return false
		visited[piece["id"]] = true
		placed.append(piece)
	return true
