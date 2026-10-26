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
		Core.make_piece(94,11,1,Vector2i(1,1)),
		# All four rotated placements must be blocked, including newly
		# supported negative coordinates to the left/top of the original grid.
		Core.make_piece(97,11,1,Vector2i(0,-1)),
		Core.make_piece(98,11,1,Vector2i(1,-1))]
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
	# Hints and the pinch-zoom label must live within the top toolbar rather
	# than the playable map or the Home button, even on narrow screens.
	var header_game := Game.new()
	var header_space: Rect2 = header_game._toolbar_hint_rect(765.0)
	if header_space.size.x < 100.0 or header_space.position.y < 0.0 or header_space.end.y > Game.TOP_HEIGHT:
		fail_case("Instruction area should be inside the top toolbar")
		return
	var heading_end := 22.0+header_game._font().get_string_size("積木小宇宙",HORIZONTAL_ALIGNMENT_LEFT,-1,29).x
	if header_space.end.x > 765.0-10.0 or header_space.position.x < heading_end+10.0:
		fail_case("Instruction text overlaps the title or Home button")
		return
	var long_tip := "積木小宇宙的說明文字不能超出回首頁按鈕左邊或遮蓋底下畫布"
	var fitted := header_game._fit_toolbar_hint(long_tip,header_space.size.x,18)
	if fitted.is_empty() or header_game._font().get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x > header_space.size.x+0.01:
		fail_case("Long instruction did not fit safely in header")
		return
	if not header_game._fit_toolbar_hint(long_tip,0.0,18).is_empty():
		fail_case("Instruction must disappear when no free header space remains")
		return
	var narrow_header := header_game._toolbar_hint_rect(190.0)
	if narrow_header.size.x != 0.0 or not header_game._fit_toolbar_hint("太窄",narrow_header.size.x).is_empty():
		fail_case("Narrow screen hint may overlap toolbar buttons")
		return
	header_game.free()
	# The floor grows when blocks approach the top, left, right or bottom.
	var Bounds = preload("res://scripts/CanvasBounds2D.gd")
	var default_bounds: Rect2i = Bounds.bounds_for([])
	if default_bounds != Rect2i(0,0,Core.COLUMNS,Core.ROWS):
		fail_case("Empty canvas must keep old 18x9 layout")
		return
	var edge_parts: Array = [
		Core.make_piece(200,0,1,Vector2i(-4,-2)),
		Core.make_piece(201,1,2,Vector2i(18,9))
	]
	var expanded: Rect2i = Bounds.bounds_for(edge_parts)
	if expanded.position.x >= 0 or expanded.position.y >= 0 or expanded.end.x <= Core.COLUMNS or expanded.end.y <= Core.ROWS:
		fail_case("Canvas did not expand automatically in all four directions")
		return
	for block in edge_parts:
		if not Core.can_place([],block) or not expanded.encloses(Core.rect_of(block)):
			fail_case("Extended map must contain newly placed bricks")
			return
	var many: Array = [Core.make_piece(202,2,1,Vector2i(40,35))]
	var large: Rect2i = Bounds.bounds_for(many)
	if large.end.x <= 40 or large.end.y <= 35:
		fail_case("Repeated extension did not cover distant bricks")
		return
	var viewport := Game.new()
	viewport.size = Vector2(1280,720)
	viewport.pieces = many.duplicate(true)
	viewport._refresh_canvas(Core.rect_of(many[0]).get_center())
	if viewport.canvas_bounds != large or viewport.grid_cell < Bounds.MIN_TOUCH_CELL:
		fail_case("Auto fit must preserve a touchable grid")
		return
	if not viewport._on_board(viewport.board_area.get_center()):
		fail_case("Expanded map must remain interactive")
		return
	viewport.free()
	# Simulate two simultaneous Android fingers: zoom in, zoom out, track midpoint,
	# reject accidental brick edits, then allow ordinary one-finger gestures.
	var touch_game := Game.new()
	touch_game.page = "play"
	touch_game.size = Vector2(1280,720)
	touch_game._refresh_canvas()
	var middle: Vector2 = touch_game.board_area.get_center()
	var original_size := touch_game.grid_cell
	var first := middle+Vector2(-60,0)
	var second := middle+Vector2(60,0)
	touch_game._touch_begin(0,first)
	if not touch_game.pressed:
		fail_case("Single finger should remain an ordinary tap")
		return
	touch_game._touch_begin(1,second)
	if not touch_game.pinch_active or touch_game.pressed or not touch_game.pinch_locked:
		fail_case("Second finger must cancel any pending placement")
		return
	var world_anchor := (middle-touch_game.grid_origin)/touch_game.grid_cell
	touch_game._touch_dragged(0,middle+Vector2(-100,0))
	touch_game._touch_dragged(1,middle+Vector2(100,0))
	if touch_game.grid_cell <= original_size or touch_game.zoom_factor <= 1.0:
		fail_case("Two fingers spread must zoom the map in")
		return
	var after_anchor := (middle-touch_game.grid_origin)/touch_game.grid_cell
	if world_anchor.distance_to(after_anchor) > 0.7:
		fail_case("Pinch zoom moved the central map point too far")
		return
	touch_game._touch_dragged(0,middle+Vector2(-30,0))
	touch_game._touch_dragged(1,middle+Vector2(30,0))
	if touch_game.grid_cell >= original_size or touch_game.zoom_factor >= 1.0:
		fail_case("Two fingers moved together must zoom the map out")
		return
	touch_game._touch_end(1,middle+Vector2(30,0))
	if not touch_game.pinch_locked or touch_game.pressed:
		fail_case("The last finger must not resume a half-finished brick gesture")
		return
	touch_game._touch_end(0,middle+Vector2(-30,0))
	if touch_game.pinch_locked or not touch_game.touch_positions.is_empty():
		fail_case("Pinch lock must clear when both fingers are lifted")
		return
	if not touch_game.pieces.is_empty() or not touch_game.history.is_empty():
		fail_case("Pinch must not place, move or rotate any bricks")
		return
	touch_game._touch_begin(0,middle)
	if not touch_game.pressed:
		fail_case("Normal one-finger control must recover after pinch")
		return
	touch_game._touch_dragged(0,middle+Vector2(70,0))
	touch_game._touch_end(0,middle+Vector2(70,0))
	if touch_game.pressed or touch_game.pinch_locked:
		fail_case("Normal gesture did not end cleanly after pinch")
		return
	touch_game.free()
	if not Store.autosave(edge_parts,"擴充畫布測試"):
		fail_case("Cannot save pieces beyond old 18x9 area")
		return
	var expanded_loaded: Dictionary = Store.load_autosave()
	if expanded_loaded.get("pieces",[]).size() != 2 or Bounds.bounds_for(expanded_loaded["pieces"]) != expanded:
		fail_case("Expanded map did not reconstruct after loading")
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
	if Core.can_place(parts,Core.make_piece(2,4,1,Vector2i(Core.WORLD_LIMIT,Core.WORLD_LIMIT))):
		fail_case("World safety boundary ignored")
		return
	if not Core.can_place(parts,Core.make_piece(4,4,1,Vector2i(17,8))):
		fail_case("Building must allow expanding beyond the original mat")
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
	# Viewing and re-opening a collected work must never generate another file.
	# Earlier app versions archived the current work on every gallery click.
	var initial_count := Store.list_gallery().size()
	var gallery_bricks: Array = [
		Core.make_piece(81001,0,4,Vector2i(8,4)),
		Core.make_piece(81002,1,6,Vector2i(1,2))
	]
	var gallery_title := "作品館重複測試"
	var first_path := Store.save_work(gallery_bricks,gallery_title)
	if first_path.is_empty() or not Store.gallery_path_valid(first_path):
		fail_case("Initial gallery save must return a safe stable path")
		return
	if Store.list_gallery().size() != initial_count+1:
		fail_case("Initial work should add exactly one gallery entry")
		return
	for repeat in 4:
		if Store.save_work(gallery_bricks,gallery_title) != first_path:
			fail_case("Saving identical work without a source must reuse old file")
			return
	if Store.list_gallery().size() != initial_count+1:
		fail_case("Saving the same work made duplicate entries")
		return
	# Old installations may already have duplicate physical files. Keep these
	# files intact, but show only one entry for identical bricks and title.
	var old_duplicate := Store.ROOT+"work_legacy_duplicate_%d.json" % randi_range(1000000,9999999)
	if not Store.write_safe(old_duplicate,{"version":2,"title":gallery_title,"pieces":gallery_bricks,"guide_id":-1,"step":0}):
		fail_case("Cannot prepare simulated old duplicate file")
		return
	if Store.list_gallery().size() != initial_count+1:
		fail_case("Historical identical work copies should be hidden, not shown")
		return
	var gallery_game := Game.new()
	gallery_game.size = Vector2(1280,720)
	var target_index := -1
	var gallery_list := Store.list_gallery()
	for i in gallery_list.size():
		if str(gallery_list[i].get("title","")) == gallery_title:
			target_index = i
			break
	if target_index < 0:
		fail_case("Saved gallery item not found")
		return
	for visit in 4:
		gallery_game._perform("gallery")
		gallery_game._perform("gallery:%d" % target_index)
		if gallery_game.gallery_file != first_path or gallery_game.pieces.size() != gallery_bricks.size():
			fail_case("Gallery open must keep original file identity and pieces")
			return
		gallery_game._perform("home")
		if Store.list_gallery().size() != initial_count+1:
			fail_case("Viewing an old work created another gallery entry")
			return
	# Tapping Collect again must update the same entry, not Save As.
	gallery_game._save_gallery()
	if gallery_game.gallery_file != first_path or Store.list_gallery().size() != initial_count+1:
		fail_case("Re-collecting old work created a second entry")
		return
	gallery_game.pieces[0]["color"] = 12
	gallery_game._save_gallery()
	if Store.list_gallery().size() != initial_count+1:
		fail_case("Saving edits to an old work created a separate entry")
		return
	var updated: Dictionary = Store.read_document(first_path)
	if updated.is_empty() or int(updated["pieces"][0]["color"]) != 12:
		fail_case("Editing an old work must update its original file")
		return
	var reopened := Game.new()
	reopened.size = Vector2(1280,720)
	reopened._restore(Store.load_autosave())
	if reopened.gallery_file != first_path:
		fail_case("Autosave lost gallery identity after app restart")
		return
	reopened._archive_existing()
	if Store.list_gallery().size() != initial_count+1:
		fail_case("Reopening after app restart archived an unwanted duplicate")
		return
	gallery_game.free()
	reopened.free()
	print("PASS: gallery repeated view, re-collect and edit reuse one file; legacy duplicates hidden")
	print("PASS: hint moved into toolbar without overlap, 2-finger pinch, touch cancellation, pan, expanding map, rotation, guides, legacy saves")
	quit(0)
