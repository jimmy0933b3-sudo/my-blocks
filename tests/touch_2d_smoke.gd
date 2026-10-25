extends SceneTree
const Core = preload("res://scripts/Blocks2D.gd")
const Guides = preload("res://scripts/Guides2D.gd")
const Store = preload("res://scripts/Save2D.gd")
const Game = preload("res://scripts/Main2D.gd")

func fail_case(message: String) -> void:
	push_error("2D validation failed: "+message)
	quit(1)

func _initialize() -> void:
	if Core.PALETTE_KINDS.size() != 8 or Core.COLORS.size() != 32:
		fail_case("Missing 2D pieces or colors")
		return
	# Palette never repeats the same size in rotated orientation.
	var unique: Dictionary = {}
	for kind in Core.PALETTE_KINDS:
		var dims := Core.size_for(kind)
		var key := "%d:%d" % [mini(dims.x,dims.y),maxi(dims.x,dims.y)]
		if unique.has(key):
			fail_case("Duplicate vertical/horizontal shape in palette")
			return
		unique[key] = true
	for legacy in [6,7,8,9]:
		var canonical := Core.canonical_kind(legacy)
		if Core.size_for(canonical,1) != Core.size_for(legacy):
			fail_case("Old rotated save incompatible with simplified palette")
			return
	var old_shape: Dictionary = {"id":90,"kind":6,"color":2,"x":2,"y":2}
	if not Core.valid_piece(old_shape) or Core.rect_of(old_shape).size != Vector2i(1,2):
		fail_case("Old vertical 2D save no longer supported")
		return
	var rotating := Core.make_piece(92,0,2,Vector2i(5,3))
	var turned: Dictionary = Core.turned_piece(rotating,[rotating])
	if turned.is_empty() or Core.rect_of(turned).size != Vector2i(1,2):
		fail_case("Rotation from horizontal to vertical failed")
		return
	var restored: Dictionary = Core.turned_piece(turned,[turned])
	if restored.is_empty() or Core.rect_of(restored).size != Vector2i(2,1):
		fail_case("Rotation back from vertical to horizontal failed")
		return
	var blockers: Array = [
		Core.make_piece(93,11,1,Vector2i(0,1)),
		Core.make_piece(94,11,1,Vector2i(1,1))]
	var corner := Core.make_piece(95,0,0,Vector2i(0,0))
	blockers.append(corner)
	if not Core.turned_piece(corner,blockers).is_empty():
		fail_case("Rotating into other pieces must be blocked")
		return
	if not Core.turned_piece(Core.make_piece(96,3,0,Vector2i(2,2)),[]).is_empty():
		fail_case("Square piece should not rotate")
		return
	var gesture := Game.new()
	var tap := Vector2(100,100)
	if gesture._register_double_tap("shape:0",tap):
		fail_case("First tap should not rotate")
		return
	if not gesture._register_double_tap("shape:0",tap):
		fail_case("Second tap should trigger rotation")
		return
	if gesture._register_double_tap("brick:10",tap):
		fail_case("Different brick must reset double-tap recognition")
		return
	gesture.free()
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
	var rotated: Array = [Core.make_piece(91,1,1,Vector2i(2,2),1)]
	if not Store.autosave(rotated,"直向測試"):
		fail_case("Rotated shape save failed")
		return
	var loaded: Dictionary = Store.load_autosave()
	if loaded.get("pieces",[]).size()!=1 or Core.rotation_of(loaded["pieces"][0])!=1:
		fail_case("Rotated piece direction not retained")
		return
	if not Store.autosave([old_shape],"舊版測試") or Core.rect_of(Store.load_autosave()["pieces"][0]).size!=Vector2i(1,2):
		fail_case("Legacy shape not retained through save/restore")
		return
	print("PASS: 8 unique shapes, double-tap recognition, rotation/undo geometry, 32 colors, guide steps, old and new saves")
	quit(0)
