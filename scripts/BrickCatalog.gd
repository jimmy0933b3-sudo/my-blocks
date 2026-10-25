extends RefCounted
## 30 standard rectangular bricks. IDs are stable for save-file compatibility.
const SIZES: Array[Vector2i] = [
	Vector2i(1,1),Vector2i(1,2),Vector2i(1,3),Vector2i(1,4),Vector2i(1,5),Vector2i(1,6),
	Vector2i(2,1),Vector2i(2,2),Vector2i(2,3),Vector2i(2,4),Vector2i(2,5),Vector2i(2,6),
	Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(3,4),Vector2i(3,5),Vector2i(3,6),
	Vector2i(4,1),Vector2i(4,2),Vector2i(4,3),Vector2i(4,4),Vector2i(4,5),Vector2i(4,6),
	Vector2i(5,1),Vector2i(5,2),Vector2i(5,3),Vector2i(5,4),Vector2i(6,1),Vector2i(6,2)
]
const COLORS: Array[String] = [
	"#E94B5A","#FF833E","#F8B93B","#FFE66B","#72CC74","#28A487","#2ABAD0","#478BDD",
	"#7164D8","#AB6BDD","#E87CB7","#F5A1A3","#8D402D","#BA7948","#D8B57B","#FFF1D3",
	"#FFFFFF","#D1DAE4","#A9B6C5","#63758A","#34475A","#262B40","#F6A0D7","#BBDE59",
	"#2F6952","#0E777D","#3157A6","#6B327C","#D77E29","#B74C40","#7F8C51","#C7A2EF"
]
static func count() -> int:
	return SIZES.size()

static func label_for(kind: int) -> String:
	if kind < 0 or kind >= SIZES.size():
		return "?"
	var s: Vector2i = SIZES[kind]
	return "%d×%d" % [s.x,s.y]

static func size_for(kind: int, rotation: int = 0) -> Vector2i:
	if kind < 0 or kind >= SIZES.size():
		return Vector2i.ONE
	var size: Vector2i = SIZES[kind]
	if posmod(rotation, 2) != 0:
		return Vector2i(size.y, size.x)
	return size

static func color_for(index: int) -> Color:
	return Color.html(COLORS[posmod(index, COLORS.size())])
