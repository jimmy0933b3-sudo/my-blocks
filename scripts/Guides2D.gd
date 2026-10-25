extends RefCounted
const Core = preload("res://scripts/Blocks2D.gd")
const NAMES: Array[String] = ["彩色小房子","嘟嘟小汽車","開心小花朵","彩虹積木塔"]
const DESCRIPTIONS: Array[String] = ["蓋一間自己的家","讓車子開上街","種出一朵大花","堆成高高的彩虹"]
# id, kind, color, x, y. Each step occupies distinct cells.
const STEPS := [
	[[1,5,2,6,5],[2,5,2,10,5],[3,1,0,7,4],[4,1,0,10,4],[5,7,3,8,2],[6,7,3,10,2],[7,0,8,8,6]],
	[[1,2,0,6,4],[2,2,0,10,4],[3,3,7,9,3],[4,3,7,7,3],[5,3,20,6,5],[6,3,20,11,5]],
	[[1,8,4,9,4],[2,3,2,8,2],[3,0,0,7,3],[4,0,0,10,3],[5,0,0,8,1],[6,0,0,8,5]],
	[[1,3,0,8,7],[2,3,1,8,5],[3,3,2,8,3],[4,3,4,8,1]]
]

static func list_guides() -> Array[String]:
	return NAMES

static func pieces_for(index: int) -> Array:
	if index < 0 or index >= STEPS.size():
		return []
	var result: Array = []
	for definition in STEPS[index]:
		var a: Array = definition
		var p := Core.make_piece(int(a[0]),int(a[1]),int(a[2]),Vector2i(int(a[3]),int(a[4])))
		if not Core.can_place(result,p):
			push_error("Impossible 2D guide step for guide %d" % index)
			return []
		result.append(p)
	return result
