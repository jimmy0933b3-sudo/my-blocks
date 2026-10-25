extends RefCounted
const Logic = preload("res://scripts/BrickLogic.gd")
const Catalog = preload("res://scripts/BrickCatalog.gd")

static func list_guides() -> Array[String]:
	return ["彩色小房子","小小汽車","彩虹高塔"]

static func pieces_for(index: int) -> Array:
	var result: Array = []
	var instructions: Array = []
	match index:
		0:
			instructions = [
				[9,3,0,-2,0,-2],[9,2,0,0,0,-2],
				[9,3,0,-2,1,-2],[9,2,0,0,1,-2],
				[3,0,0,-2,2,-2],[3,0,0,1,2,-2],
				[3,0,0,-2,3,-2],[3,0,0,1,3,-2]
			]
		1:
			instructions = [
				[9,7,0,-2,0,-1],[9,7,0,0,0,-1],
				[7,0,0,-2,1,-1],[7,0,0,0,1,-1],
				[0,16,0,-2,2,-1],[0,16,0,1,2,-1]
			]
		2:
			instructions = [
				[7,0,0,-1,0,-1],[7,1,0,-1,1,-1],
				[7,2,0,-1,2,-1],[7,3,0,-1,3,-1],
				[7,4,0,-1,4,-1],[7,5,0,-1,5,-1]
			]
		_:
			return result
	for i in instructions.size():
		var b: Array = instructions[i]
		var p := Logic.part(int(b[0]),int(b[1]),int(b[2]),Vector3i(int(b[3]),int(b[4]),int(b[5])),i+1)
		if not Logic.can_place(result,p):
			push_error("Invalid blueprint %d step %d" % [index,i])
			return []
		result.append(p)
	return result
