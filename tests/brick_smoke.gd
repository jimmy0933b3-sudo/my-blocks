extends SceneTree
const Catalog = preload("res://scripts/BrickCatalog.gd")
const Logic = preload("res://scripts/BrickLogic.gd")
const Guides = preload("res://scripts/Blueprints.gd")
const Store = preload("res://scripts/SaveStore.gd")
func _initialize() -> void:
	if Catalog.count() != 30 or Catalog.COLORS.size() != 32:
		push_error("Invalid catalogue")
		quit(1)
		return
	var base := Logic.part(9,0,0,Vector3i(0,0,0),1)
	var pieces: Array = [base]
	if Logic.can_place(pieces,Logic.part(9,1,0,Vector3i(1,0,0),2)):
		push_error("Overlap allowed")
		quit(1)
		return
	if Logic.can_place(pieces,Logic.part(9,1,0,Vector3i(5,1,0),2)):
		push_error("Floating brick allowed")
		quit(1)
		return
	var upper := Logic.part(7,1,0,Vector3i(0,1,0),2)
	if not Logic.can_place(pieces,upper):
		push_error("Valid stacking rejected")
		quit(1)
		return
	pieces.append(upper)
	if Logic.has_orphans(pieces) or Catalog.size_for(9,1) != Vector2i(4,2):
		push_error("Support or rotation failed")
		quit(1)
		return
	for id in Guides.list_guides().size():
		var guide: Array = Guides.pieces_for(id)
		if guide.size() < 6:
			push_error("Invalid blueprint")
			quit(1)
			return
		var placed: Array = []
		for p in guide:
			if not Logic.can_place(placed,p):
				push_error("Impossible blueprint step")
				quit(1)
				return
			placed.append(p)
	if not Store.save_autosave(pieces,"CI 測試",3):
		push_error("Failed to save")
		quit(1)
		return
	if Store.load_autosave().get("pieces",[]).size() != 2:
		push_error("Failed to restore")
		quit(1)
		return
	print("PASS: bricks, overlapping, support, rotation, guided plans and save/restore")
	quit(0)
