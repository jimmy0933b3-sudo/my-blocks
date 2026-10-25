extends Node3D
## Self-contained landscape 3D brick builder. All controls are large touchscreen targets.
const Catalog = preload("res://scripts/BrickCatalog.gd")
const Logic = preload("res://scripts/BrickLogic.gd")
const Visual = preload("res://scripts/BrickVisual.gd")
const Store = preload("res://scripts/SaveStore.gd")
const Guides = preload("res://scripts/Blueprints.gd")

var bricks: Array = []
var selected_kind := 9
var selected_color := 0
var selected_rotation := 0
var selected_layer := 0
var next_id := 1
var guide_id := -1
var guide_step := 0
var work_title := "我的積木作品"
var choosing_existing := false
var moving_id := -1
var selected_id := -1
var undo_stack: Array = []
var redo_stack: Array = []
var camera_yaw := 0.58
var camera_pitch := 0.67
var camera_distance := 19.0
var screen_mode := "menu"
var ghost_cell := Vector3i(999,999,999)
var guide_parts: Array = []

var camera: Camera3D
var pieces_root: Node3D
var ghost_root: Node3D
var interface_layer: CanvasLayer
var menu: Control
var builder_ui: Control
var title_text: Label
var hint_text: Label
var count_text: Label
var layer_text: Label
var guide_button: Button
var palette_row: HBoxContainer
var brick_row: HBoxContainer
var autosave_timer: Timer
var notice_dialog: ConfirmationDialog

func _ready() -> void:
	_make_environment()
	_make_ui()
	autosave_timer = Timer.new()
	autosave_timer.one_shot = true
	autosave_timer.wait_time = 0.75
	add_child(autosave_timer)
	autosave_timer.timeout.connect(_save_now)
	var old := Store.load_autosave()
	if not old.is_empty():
		_restore_document(old)
	_show_menu()
	_update_camera()

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#BDEAFF")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFFFFF")
	env.ambient_light_energy = 0.75
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-40,0)
	light.light_energy = 1.1
	add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 50.0
	add_child(camera)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(25*Logic.UNIT,0.18,25*Logic.UNIT)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.15
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#8BC88F")
	floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-12,13):
		var d := float(i)*Logic.UNIT
		lines.surface_add_vertex(Vector3(d,0.005,-12*Logic.UNIT))
		lines.surface_add_vertex(Vector3(d,0.005,12*Logic.UNIT))
		lines.surface_add_vertex(Vector3(-12*Logic.UNIT,0.005,d))
		lines.surface_add_vertex(Vector3(12*Logic.UNIT,0.005,d))
	lines.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = lines
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("#C4E6BE")
	grid.material_override = gm
	add_child(grid)
	pieces_root = Node3D.new()
	pieces_root.name = "Bricks"
	add_child(pieces_root)
	ghost_root = Node3D.new()
	ghost_root.name = "Preview"
	add_child(ghost_root)

func _style(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(2)
	s.content_margin_left = 12
	s.content_margin_top = 9
	s.content_margin_right = 12
	s.content_margin_bottom = 9
	return s

func _button(label_text: String, callback: Callable, bg: Color = Color("#FDF7E8"), min_width: int = 80) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(min_width,58)
	b.add_theme_color_override("font_color",Color("#29465F"))
	b.add_theme_color_override("font_hover_color",Color("#173D5D"))
	b.add_theme_color_override("font_pressed_color",Color("#173D5D"))
	b.add_theme_font_size_override("font_size",21)
	b.add_theme_stylebox_override("normal",_style(bg))
	b.add_theme_stylebox_override("hover",_style(bg.lightened(0.08)))
	b.add_theme_stylebox_override("pressed",_style(bg.darkened(0.06)))
	b.pressed.connect(callback)
	return b

func _label(value: String, size: int = 22, color: Color = Color("#24445F")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _make_ui() -> void:
	interface_layer = CanvasLayer.new()
	add_child(interface_layer)
	builder_ui = Control.new()
	builder_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	builder_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface_layer.add_child(builder_ui)
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_bottom = 83
	top.add_theme_stylebox_override("panel",_style(Color("#4E8DB9"),0))
	builder_ui.add_child(top)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",9)
	top.add_child(toolbar)
	toolbar.add_child(_button("⌂ 首頁",_show_menu,Color("#FFE6AC"),100))
	title_text = _label(work_title,24,Color.WHITE)
	title_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title_text)
	toolbar.add_child(_button("↶",_undo,Color("#FAF2DB"),62))
	toolbar.add_child(_button("↷",_redo,Color("#FAF2DB"),62))
	toolbar.add_child(_button("↻",_rotate,Color("#F5D9B2"),62))
	toolbar.add_child(_button("＋層",_layer_up,Color("#D9F5F0"),75))
	toolbar.add_child(_button("－層",_layer_down,Color("#D9F5F0"),75))
	layer_text = _label("第 1 層",20,Color.WHITE)
	toolbar.add_child(layer_text)
	var side := VBoxContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.offset_left = -153
	side.offset_right = -8
	side.offset_top = 106
	side.add_theme_constant_override("separation",8)
	builder_ui.add_child(side)
	side.add_child(_button("◀ 轉視角",func(): _orbit(-0.28),Color("#E9F5F8"),136))
	side.add_child(_button("轉視角 ▶",func(): _orbit(0.28),Color("#E9F5F8"),136))
	side.add_child(_button("放大 ＋",func(): _zoom(-2.1),Color("#E9F5F8"),136))
	side.add_child(_button("縮小 －",func(): _zoom(2.1),Color("#E9F5F8"),136))
	side.add_child(_button("選取 / 移動",_toggle_select,Color("#FFF0C1"),136))
	side.add_child(_button("換顏色",_recolor_selected,Color("#FFF0C1"),136))
	side.add_child(_button("刪除選取",_delete_selected,Color("#F7D5DA"),136))
	side.add_child(_button("存入作品館",_save_work,Color("#D7EACA"),136))
	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -196
	bottom.add_theme_stylebox_override("panel",_style(Color("#F9EAC9"),13))
	builder_ui.add_child(bottom)
	var strip := VBoxContainer.new()
	strip.add_theme_constant_override("separation",4)
	bottom.add_child(strip)
	var info_line := HBoxContainer.new()
	strip.add_child(info_line)
	hint_text = _label("點擊下方積木，再點綠色底板放置",19)
	hint_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_line.add_child(hint_text)
	count_text = _label("0 個積木",18)
	info_line.add_child(count_text)
	guide_button = _button("放上這塊 ✓",_guided_place,Color("#C6E7AE"),150)
	guide_button.visible = false
	info_line.add_child(guide_button)
	var brick_scroll := ScrollContainer.new()
	brick_scroll.custom_minimum_size = Vector2(0,67)
	brick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	brick_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.add_child(brick_scroll)
	brick_row = HBoxContainer.new()
	brick_row.add_theme_constant_override("separation",6)
	brick_scroll.add_child(brick_row)
	for i in range(Catalog.count()):
		brick_row.add_child(_button(Catalog.label_for(i),_choose_kind.bind(i),Color("#FFFFFF"),77))
	var color_scroll := ScrollContainer.new()
	color_scroll.custom_minimum_size = Vector2(0,61)
	color_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	color_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.add_child(color_scroll)
	palette_row = HBoxContainer.new()
	palette_row.add_theme_constant_override("separation",6)
	color_scroll.add_child(palette_row)
	for i in range(Catalog.COLORS.size()):
		var btn := _button("●",_choose_color.bind(i),Catalog.color_for(i),53)
		btn.add_theme_color_override("font_color",Color("#FFFFFF") if i > 16 else Color("#28394B"))
		btn.custom_minimum_size = Vector2(53,50)
		palette_row.add_child(btn)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface_layer.add_child(menu)
	notice_dialog = ConfirmationDialog.new()
	notice_dialog.title = "確認"
	notice_dialog.ok_button_text = "確定"
	notice_dialog.cancel_button_text = "取消"
	interface_layer.add_child(notice_dialog)

func _clear_container(target: Node) -> void:
	for child in target.get_children():
		target.remove_child(child)
		child.queue_free()

func _menu_base(heading: String, subheading: String) -> VBoxContainer:
	_clear_container(menu)
	menu.visible = true
	builder_ui.visible = false
	screen_mode = "menu"
	var shade := ColorRect.new()
	shade.color = Color("#D4F0FA",0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760,0)
	card.add_theme_stylebox_override("panel",_style(Color("#FFFFFF",0.95),28))
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",14)
	card.add_child(v)
	var heading_label := _label(heading,43,Color("#2E6A94"))
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(heading_label)
	var sub := _label(subheading,22,Color("#677E91"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	return v

func _show_menu() -> void:
	_save_now()
	var v := _menu_base("積木小宇宙", "選一個遊戲，開始積木冒險！")
	v.add_child(_button("🧱 自由創作",_open_free,Color("#FFE4A6"),460))
	v.add_child(_button("🏠 跟著蓋積木",_show_guides,Color("#BEE8D3"),460))
	v.add_child(_button("🌳 我的積木世界",_show_world,Color("#CFE7FC"),460))
	v.add_child(_button("★ 作品收藏館",_show_gallery,Color("#F2DCF9"),460))
	v.add_child(_label("離線可玩 · 自動保存 · 4～8 歲",17,Color("#667F90")))

func _open_free() -> void:
	guide_id = -1
	guide_parts.clear()
	screen_mode = "builder"
	menu.visible = false
	builder_ui.visible = true
	if bricks.is_empty():
		work_title = "我的積木作品"
	_set_hint("選積木 → 選顏色 → 點擊底板放置")
	_render_all()

func _show_guides() -> void:
	var v := _menu_base("跟著蓋", "照著透明積木，一步步完成作品")
	for i in range(Guides.list_guides().size()):
		var name: String = Guides.list_guides()[i]
		v.add_child(_button("%d   %s" % [i+1,name],_start_guide.bind(i),Color("#DBEAC7"),410))
	v.add_child(_button("返回首頁",_show_menu,Color("#F1F1F1"),260))

func _start_guide(index: int) -> void:
	guide_parts = Guides.pieces_for(index)
	if guide_parts.is_empty():
		return
	guide_id = index
	guide_step = 0
	bricks.clear()
	next_id = 1
	undo_stack.clear()
	redo_stack.clear()
	work_title = Guides.list_guides()[index]
	screen_mode = "guide"
	menu.visible = false
	builder_ui.visible = true
	_set_guide_part()
	_render_all()
	_schedule_save()

func _set_guide_part() -> void:
	if guide_id == -1:
		return
	if guide_step >= guide_parts.size():
		_set_hint("完成了！按「存入作品館」收藏你的作品！")
		guide_button.visible = false
		_clear_container(ghost_root)
		return
	var next: Dictionary = guide_parts[guide_step]
	selected_kind = int(next["kind"])
	selected_color = int(next["color"])
	selected_rotation = int(next["rotation"])
	selected_layer = int(next["y"])
	_set_hint("第 %d / %d 步：放一塊 %s 積木" % [guide_step+1,guide_parts.size(),Catalog.label_for(selected_kind)])
	guide_button.visible = true
	_update_ghost(Logic.cell_of(next))

func _guided_place() -> void:
	if screen_mode != "guide" or guide_step >= guide_parts.size():
		return
	var item: Dictionary = guide_parts[guide_step].duplicate(true)
	item["id"] = next_id
	if not Logic.can_place(bricks,item):
		_set_hint("這一步無法放置，請檢查已放置的積木")
		return
	_record_undo()
	bricks.append(item)
	next_id += 1
	guide_step += 1
	_set_guide_part()
	_after_edit()

func _show_gallery() -> void:
	var v := _menu_base("作品收藏館", "選擇你想繼續製作的作品")
	var saved := Store.list_works()
	if saved.is_empty():
		v.add_child(_label("還沒有收藏的作品，先蓋一個吧！",22))
	for path in saved.slice(0,6):
		var data := Store.read_file(path)
		if data.is_empty():
			continue
		v.add_child(_button("🧱 " + str(data.get("title","我的作品")), _open_saved.bind(path),Color("#F5E5B7"),450))
	v.add_child(_button("返回首頁",_show_menu,Color("#F1F1F1"),280))

func _open_saved(path: String) -> void:
	var d := Store.read_file(path)
	if d.is_empty():
		return
	_restore_document(d)
	_open_free()

func _show_world() -> void:
	var v := _menu_base("我的積木世界", "目前先將喜歡的作品收藏，之後能放進自己的小世界")
	v.add_child(_label("積木城市與車輛互動將在後續版本加入。",21))
	v.add_child(_button("前往作品收藏館",_show_gallery,Color("#BDE8D6"),390))
	v.add_child(_button("返回首頁",_show_menu,Color("#F1F1F1"),260))

func _choose_kind(index: int) -> void:
	selected_kind = index
	if choosing_existing and selected_id >= 0:
		_set_hint("已選取積木，按「選取 / 移動」進行移動")
	else:
		_set_hint("已選 %s，點擊畫布放置" % Catalog.label_for(index))
	_update_ghost(ghost_cell,true)

func _choose_color(index: int) -> void:
	selected_color = index
	_set_hint("已選新顏色，可放置積木或替選取的積木換色")
	_update_ghost(ghost_cell,true)

func _rotate() -> void:
	if choosing_existing and selected_id >= 0:
		var index := _index_by_id(selected_id)
		if index >= 0:
			var candidate: Dictionary = bricks[index].duplicate(true)
			candidate["rotation"] = posmod(int(candidate["rotation"])+1,4)
			if Logic.can_place(bricks,candidate,selected_id):
				_record_undo()
				bricks[index] = candidate
				_after_edit()
				return
	selected_rotation = posmod(selected_rotation+1,4)
	_update_ghost(ghost_cell,true)

func _layer_up() -> void:
	selected_layer = mini(Logic.MAX_LAYER,selected_layer+1)
	_update_layer()
	_update_ghost(ghost_cell,true)

func _layer_down() -> void:
	selected_layer = maxi(0,selected_layer-1)
	_update_layer()
	_update_ghost(ghost_cell,true)

func _update_layer() -> void:
	if layer_text != null:
		layer_text.text = "第 %d 層" % [selected_layer+1]

func _toggle_select() -> void:
	if choosing_existing:
		choosing_existing = false
		selected_id = -1
		moving_id = -1
		_set_hint("放置模式：點畫布放積木")
	else:
		choosing_existing = true
		moving_id = -1
		_set_hint("選取模式：點一塊積木；再點新位置就可以移動")

func _recolor_selected() -> void:
	var index := _index_by_id(selected_id)
	if index < 0:
		_set_hint("請先按「選取 / 移動」選一塊積木")
		return
	_record_undo()
	bricks[index]["color"] = selected_color
	_after_edit()

func _delete_selected() -> void:
	var index := _index_by_id(selected_id)
	if index < 0:
		_set_hint("請先選取要拆除的積木")
		return
	var proposed: Array = bricks.duplicate(true)
	proposed.remove_at(index)
	if Logic.has_orphans(proposed):
		_set_hint("上方還有積木支撐在這塊上，請先拆除上方積木")
		return
	_record_undo()
	bricks = proposed
	selected_id = -1
	moving_id = -1
	_after_edit()

func _index_by_id(identifier: int) -> int:
	for i in bricks.size():
		if int(bricks[i].get("id",-1)) == identifier:
			return i
	return -1

func _save_work() -> void:
	var path := Store.save_work(bricks,work_title)
	_set_hint("已存入作品收藏館 ✓" if not path.is_empty() else "儲存失敗，請檢查裝置空間")

func _record_undo() -> void:
	undo_stack.append(bricks.duplicate(true))
	if undo_stack.size() > 100:
		undo_stack.pop_front()
	redo_stack.clear()

func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(bricks.duplicate(true))
	bricks = undo_stack.pop_back()
	selected_id = -1
	_after_edit()

func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(bricks.duplicate(true))
	bricks = redo_stack.pop_back()
	selected_id = -1
	_after_edit()

func _after_edit() -> void:
	_render_all()
	_schedule_save()

func _schedule_save() -> void:
	if autosave_timer != null:
		autosave_timer.start()

func _save_now() -> void:
	if autosave_timer != null and not autosave_timer.is_stopped():
		autosave_timer.stop()
	if bricks.is_empty() and guide_id < 0:
		return
	Store.save_autosave(bricks,work_title,next_id,guide_id,guide_step)

func _restore_document(d: Dictionary) -> void:
	bricks = d.get("pieces",[]).duplicate(true)
	work_title = str(d.get("title","我的積木作品"))
	next_id = int(d.get("next_id",1))
	for p in bricks:
		next_id = maxi(next_id,int(p["id"])+1)
	guide_id = int(d.get("guide_id",-1))
	guide_step = int(d.get("step",0))
	guide_parts = Guides.pieces_for(guide_id) if guide_id >= 0 else []
	undo_stack.clear()
	redo_stack.clear()

func _render_all() -> void:
	_clear_container(pieces_root)
	for p in bricks:
		var node := Visual.create_part(p)
		pieces_root.add_child(node)
	if count_text != null:
		count_text.text = "%d / %d 塊" % [bricks.size(),Logic.MAX_PIECES]
	if title_text != null:
		title_text.text = work_title
	_update_layer()
	if screen_mode == "guide":
		_set_guide_part()
	else:
		_update_ghost(ghost_cell,true)

func _update_ghost(cell: Vector3i, force: bool = false) -> void:
	if screen_mode != "builder" and screen_mode != "guide":
		_clear_container(ghost_root)
		return
	if screen_mode == "guide":
		if guide_step >= guide_parts.size():
			_clear_container(ghost_root)
			return
		cell = Logic.cell_of(guide_parts[guide_step])
	if not force and cell == ghost_cell:
		return
	ghost_cell = cell
	_clear_container(ghost_root)
	if cell.x == 999:
		return
	var p := Logic.part(selected_kind,selected_color,selected_rotation,cell,-1)
	if Logic.can_place(bricks,p,moving_id):
		ghost_root.add_child(Visual.create_part(p,true))

func _set_hint(value: String) -> void:
	if hint_text != null:
		hint_text.text = value

func _update_camera() -> void:
	if camera == null:
		return
	var orbit := Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))
	camera.position = orbit*camera_distance + Vector3(0,0.6,0)
	camera.look_at(Vector3(0,0.6,0),Vector3.UP)

func _orbit(delta: float) -> void:
	camera_yaw += delta
	_update_camera()

func _zoom(delta: float) -> void:
	camera_distance = clampf(camera_distance+delta,6.5,35.0)
	_update_camera()

func _hit_plane(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var plane := Plane(Vector3.UP,float(selected_layer)*Logic.HEIGHT)
	var hit: Variant = plane.intersects_ray(from,direction)
	if hit == null:
		return null
	return Vector3i(floori(hit.x/Logic.UNIT),selected_layer,floori(hit.z/Logic.UNIT))

func _select_part(screen_position: Vector2) -> bool:
	var from := camera.project_ray_origin(screen_position)
	var dir := camera.project_ray_normal(screen_position)
	var closest := INF
	var found := -1
	for p in bricks:
		var c := Logic.cell_of(p)
		var s := Catalog.size_for(int(p["kind"]),int(p["rotation"]))
		var box := AABB(Logic.world_position(p), Vector3(s.x*Logic.UNIT,Logic.HEIGHT,s.y*Logic.UNIT))
		var hit: Variant = box.intersects_ray(from,dir)
		if hit != null:
			var distance: float = from.distance_to(hit)
			if distance < closest:
				closest = distance
				found = int(p["id"])
	if found == -1:
		return false
	selected_id = found
	moving_id = found
	var i := _index_by_id(found)
	selected_kind = int(bricks[i]["kind"])
	selected_color = int(bricks[i]["color"])
	selected_rotation = int(bricks[i]["rotation"])
	selected_layer = int(bricks[i]["y"])
	_update_layer()
	_set_hint("已選取積木。可換色、旋轉、刪除；點新位置移動")
	return true

func _place_at(screen_position: Vector2) -> void:
	if screen_mode != "builder":
		return
	if choosing_existing and moving_id < 0:
		_select_part(screen_position)
		return
	if choosing_existing and moving_id >= 0 and _select_part(screen_position):
		return
	var c: Variant = _hit_plane(screen_position)
	if c == null:
		return
	var item := Logic.part(selected_kind,selected_color,selected_rotation,c,next_id)
	if not Logic.can_place(bricks,item,moving_id):
		_set_hint("這裡不能放！請試試底板或其他積木上方")
		return
	_record_undo()
	if moving_id >= 0:
		var i := _index_by_id(moving_id)
		if i >= 0:
			item["id"] = moving_id
			bricks[i] = item
		moving_id = -1
		selected_id = -1
	else:
		bricks.append(item)
		next_id += 1
	_set_hint("放好了！繼續蓋積木吧 ✓")
	_after_edit()

func _unhandled_input(event: InputEvent) -> void:
	if screen_mode != "builder" and screen_mode != "guide":
		return
	if event is InputEventScreenDrag:
		if screen_mode == "builder":
			var position: Variant = _hit_plane(event.position)
			if position != null:
				_update_ghost(position)
	elif event is InputEventScreenTouch and not event.pressed:
		_place_at(event.position)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_orbit(-event.relative.x*0.008)
		elif screen_mode == "builder":
			var position: Variant = _hit_plane(event.position)
			if position != null:
				_update_ghost(position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_place_at(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(0.9)
	elif event is InputEventMagnifyGesture:
		_zoom((1.0-event.factor)*4.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
