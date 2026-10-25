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

static func size_for(kind: int) -> Vector2i:
	if kind < 0 or kind >= SHAPES.size():
		return Vector2i.ONE
	return SHAPES[kind]

static func shape_label(kind: int) -> String:
	var s := size_for(kind)
	return "%d×%d" % [s.x,s.y]

static func color_for(index: int) -> Color:
	return Color.html(COLORS[posmod(index,COLORS.size())])

static func make_piece(id: int, kind: int, color_id: int, pos: Vector2i) -> Dictionary:
	return {"id":id,"kind":kind,"color":color_id,"x":pos.x,"y":pos.y}

static func cell_of(piece: Dictionary) -> Vector2i:
	return Vector2i(int(piece.get("x",0)),int(piece.get("y",0)))

static func rect_of(piece: Dictionary) -> Rect2i:
	return Rect2i(cell_of(piece),size_for(int(piece["kind"])))

static func valid_piece(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	for key in ["id","kind","color","x","y"]:
		if not data.has(key) or not (data[key] is int):
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
