extends SceneTree
const Core = preload("res://scripts/Blocks2D.gd")
const Guides = preload("res://scripts/Guides2D.gd")
const Store = preload("res://scripts/Save2D.gd")

func fail_case(message: String) -> void:
	push_error("2D validation failed: "+message)
	quit(1)

func _initialize() -> void:
	if Core.SHAPES.size() < 10 or Core.COLORS.size() != 32:
		fail_case("Missing 2D pieces or colors")
		return
	var base := Core.make_piece(1,3,0,Vector2i(4,4))
	var parts: Array = []
	if not Core.can_place(parts,base):
		fail_case("Cannot place base brick")
		return
	parts.append(base)
	if Core.can_place(parts,Core.make_piece(2,0,1,Vector2i(5,5))):
		fail_case("Overlapping 2D bricks")
		return
	if Core.can_place(parts,Core.make_piece(2,4,1,Vector2i(17,8))):
		fail_case("Out-of-bounds brick")
		return
	var adjacent := Core.make_piece(2,0,1,Vector2i(6,4))
	if not Core.can_place(parts,adjacent):
		fail_case("Adjacent bricks cannot snap")
		return
	parts.append(adjacent)
	var moved: Dictionary = base.duplicate(true)
	moved["x"] = 9
	moved["y"] = 3
	if not Core.can_place(parts,moved,1):
		fail_case("Moving brick with ignored self cannot snap")
		return
	if not Core.document_valid({"version":2,"pieces":parts}):
		fail_case("Valid save document rejected")
		return
	if Core.document_valid({"version":2,"pieces":[base,base]}):
		fail_case("Duplicate ID accepted")
		return
	if Core.document_valid({"version":2,"pieces":[base,Core.make_piece(3,0,0,Vector2i(4,4))]}):
		fail_case("Overlapping save accepted")
		return
	for i in range(Guides.NAMES.size()):
		var blocks: Array = Guides.pieces_for(i)
		if blocks.size() < 4:
			fail_case("Guide %d has no steps" % i)
			return
		var built: Array = []
		for block in blocks:
			if not Core.can_place(built,block):
				fail_case("Guide %d has invalid drag target" % i)
				return
			built.append(block)
	if not Store.autosave(parts,"2D CI 測試"):
		fail_case("2D autosave failed")
		return
	if Store.load_autosave().get("pieces",[]).size() != parts.size():
		fail_case("2D autosave restore failed")
		return
	print("PASS: 2D shapes, collisions, snapping, movement, guide targets, save/restore")
	quit(0)
