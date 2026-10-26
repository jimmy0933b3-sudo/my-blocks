extends Control
## 2D touch-first blocks: drag from a scrollable tray, swipe a placed brick to move it.
const Core = preload("res://scripts/Blocks2D.gd")
const Guides = preload("res://scripts/Guides2D.gd")
const Store = preload("res://scripts/Save2D.gd")
const CanvasBounds = preload("res://scripts/CanvasBounds2D.gd")

const TOP_HEIGHT := 78.0
const PALETTE_HEIGHT := 160.0
const SHAPE_WIDTH := 116.0
const COLOR_WIDTH := 66.0

var page := "home"
var pieces: Array = []
var next_id := 1
var selected_kind := 3
var selected_rotation := 0
var palette_rotations: Dictionary = {}
var selected_color := 0
var selected_id := -1
var guide_index := -1
var guide_step := 0
var guide_parts: Array = []
var work_title := "我的積木作品"
# Keeps the gallery file identity across viewing, editing, navigation and restarts.
var gallery_file := ""
var notice := "把下面的積木往上滑，就可以開始拼囉！"
var history: Array = []
var future: Array = []
var shape_scroll := 0.0
var color_scroll := 0.0

var board_area: Rect2
var grid_origin := Vector2.ZERO
var grid_cell := 40.0
var canvas_bounds: Rect2i = Rect2i(0,0,Core.COLUMNS,Core.ROWS)
var focus_cell := Vector2(Core.COLUMNS*0.5,Core.ROWS*0.5)
var pan_offset := Vector2.ZERO
# Relative to the automatic fit size. Manual pinch never changes brick coordinates.
const MIN_ZOOM := 0.55
const MAX_ZOOM := 3.0
var zoom_factor := 1.0
var touch_positions: Dictionary = {}
var pinch_locked := false
var pinch_active := false
var pinch_begin_distance := 1.0
var pinch_begin_zoom := 1.0
var pinch_anchor_cell := Vector2.ZERO
var menu_buttons: Array = []
var toolbar_buttons: Array = []
var touch_active := false
var pressed := false
var start_point := Vector2.ZERO
var last_point := Vector2.ZERO
var pointer_point := Vector2.ZERO
var gesture := ""
var pressed_shape := -1
var pressed_color := -1
var dragged_id := -1
var drag_start_cell := Vector2i.ZERO
var preview_cell := Vector2i(-100,-100)
var autosave_timer: Timer
const DOUBLE_TAP_MSEC := 420
const TAP_MAX_MOVE := 25.0
var last_tap_time := -10000
var last_tap_target := ""
var last_tap_position := Vector2.ZERO
var last_touch_msec := -10000

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_resized)
	autosave_timer = Timer.new()
	autosave_timer.one_shot = true
	autosave_timer.wait_time = 0.65
	add_child(autosave_timer)
	autosave_timer.timeout.connect(_save_now)
	var data := Store.load_autosave()
	if not data.is_empty():
		_restore(data)
	_layout()
	queue_redraw()

func _on_resized() -> void:
	size = get_viewport_rect().size
	_layout()
	queue_redraw()

func _layout() -> void:
	board_area = Rect2(Vector2(18,TOP_HEIGHT+6),Vector2(maxf(200.0,size.x-36.0),maxf(120.0,size.y-TOP_HEIGHT-PALETTE_HEIGHT-18.0)))
	grid_cell = clampf(CanvasBounds.fit_cell(board_area.size,canvas_bounds)*zoom_factor,16.0,148.0)
	var world_center := Vector2(canvas_bounds.position)+Vector2(canvas_bounds.size)*0.5
	var center := world_center if CanvasBounds.fully_visible(board_area.size,canvas_bounds,grid_cell) else focus_cell
	grid_origin = board_area.get_center()-center*grid_cell+pan_offset
	# Fully fitted maps stay centered. Large maps pan but maintain a finger-sized cell.
	var top_left := grid_origin+Vector2(canvas_bounds.position)*grid_cell
	var extent := Vector2(canvas_bounds.size)*grid_cell
	var near := board_area.position+Vector2(7,7)
	var far := board_area.end-Vector2(7,7)
	if extent.x <= board_area.size.x-14 and is_equal_approx(zoom_factor,1.0):
		grid_origin.x += board_area.get_center().x-(top_left.x+extent.x*0.5)
	else:
		grid_origin.x += clampf(top_left.x,mini(near.x,far.x-extent.x),maxf(near.x,far.x-extent.x))-top_left.x
	if extent.y <= board_area.size.y-14 and is_equal_approx(zoom_factor,1.0):
		grid_origin.y += board_area.get_center().y-(top_left.y+extent.y*0.5)
	else:
		grid_origin.y += clampf(top_left.y,minf(near.y,far.y-extent.y),maxf(near.y,far.y-extent.y))-top_left.y
	pan_offset = grid_origin-(board_area.get_center()-center*grid_cell)

func _refresh_canvas(focus: Vector2 = Vector2(INF,INF)) -> void:
	var previous := canvas_bounds
	canvas_bounds = CanvasBounds.bounds_for(pieces)
	if canvas_bounds != previous:
		pan_offset = Vector2.ZERO
		if is_finite(focus.x) and is_finite(focus.y):
			focus_cell = focus
	_layout()
	queue_redraw()

func _font() -> Font:
	return ThemeDB.fallback_font

func _text(value: String, at: Vector2, font_size: int = 22, color: Color = Color("#30475B")) -> void:
	draw_string(_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _card(rect: Rect2, color: Color, radius: int = 16, stroke: Color = Color.TRANSPARENT) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if stroke.a > 0.0:
		box.border_color = stroke
		box.set_border_width_all(3)
	draw_style_box(box,rect)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#DFF4FC"))
	if page == "home" or page == "guides" or page == "gallery":
		_draw_menu()
	else:
		_draw_game()

func _draw_menu() -> void:
	menu_buttons.clear()
	toolbar_buttons.clear()
	var title := "積木小宇宙"
	var subtitle := "滑一滑，拼出你的小小世界！"
	if page == "guides":
		title = "跟著圖案玩"
		subtitle = "把積木拖到亮亮的提示框裡"
	elif page == "gallery":
		title = "我的作品館"
		subtitle = "每個小作品都值得被收藏"
	_card(Rect2(Vector2(22,20),Vector2(size.x-44,size.y-40)),Color("#FFFDF7"),25)
	_text("✦",Vector2(size.x*0.5-245,104),40,Color("#FFB85A"))
	_text(title,Vector2(size.x*0.5-155,108),43,Color("#447DA6"))
	_text(subtitle,Vector2(size.x*0.5-196,151),23,Color("#7B95A3"))
	var labels: Array = []
	var actions: Array = []
	if page == "home":
		if not pieces.is_empty():
			labels.append("繼續玩我的積木")
			actions.append("continue")
		labels.append_array(["開始新作品","跟著圖案玩","我的作品館"])
		actions.append_array(["new","guides","gallery"])
	elif page == "guides":
		for i in Guides.NAMES.size():
			labels.append(Guides.NAMES[i])
			actions.append("guide:%d" % i)
		labels.append("返回首頁")
		actions.append("home")
	else:
		var saves := Store.list_gallery()
		for i in mini(saves.size(),5):
			var work: Dictionary = saves[i]
			labels.append("%s   ·   %d 塊積木" % [str(work.get("title","我的作品")),work["pieces"].size()])
			actions.append("gallery:%d" % i)
		if labels.is_empty():
			_text("還沒有作品，先玩一個吧！",Vector2(size.x*0.5-200,size.y*0.5),25)
		labels.append("返回首頁")
		actions.append("home")
	var button_height := minf(79.0,maxf(54.0,(size.y-228)/maxi(1,labels.size())))
	var gap := 9.0
	var start_y := 180.0
	for i in labels.size():
		var rect := Rect2(Vector2(size.x*0.5-270,start_y+i*(button_height+gap)),Vector2(540,button_height))
		var shade := Color("#FFE7AC") if i%3==0 else (Color("#CFF0DE") if i%3==1 else Color("#D7EAFB"))
		_card(rect,shade,22)
		var label := str(labels[i])
		_text(label,rect.position+Vector2(36,button_height*0.5+9),26,Color("#365D73"))
		_text("›",rect.position+Vector2(rect.size.x-43,button_height*0.5+11),35,Color("#4B83A0"))
		menu_buttons.append({"rect":rect,"action":str(actions[i])})

func _toolbar_hint_rect(home_left: float) -> Rect2:
	# The instruction lives entirely inside the blue header, between the
	# application title and the left edge of the Home button.
	var title_width := _font().get_string_size("積木小宇宙",HORIZONTAL_ALIGNMENT_LEFT,-1,29).x
	var left := 22.0+title_width+22.0
	var right := home_left-12.0
	# On compact screens a one-character hint is not useful. Hide it rather
	# than risk crowding the title or the navigation button.
	var usable_width := maxf(0.0,right-left)
	if usable_width < 110.0:
		usable_width = 0.0
	return Rect2(Vector2(left,9),Vector2(usable_width,58.0))

func _fit_toolbar_hint(message: String, available: float, font_size: int = 18) -> String:
	if available < 18.0:
		return ""
	if _font().get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= available:
		return message
	var suffix := "…"
	var shortened := message
	while not shortened.is_empty():
		shortened = shortened.substr(0,shortened.length()-1)
		if _font().get_string_size(shortened+suffix,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= available:
			return shortened+suffix
	return ""

func _draw_game() -> void:
	menu_buttons.clear()
	toolbar_buttons.clear()
	_card(Rect2(Vector2.ZERO,Vector2(size.x,TOP_HEIGHT)),Color("#65A6D7"),0)
	_text("積木小宇宙",Vector2(22,50),29,Color.WHITE)
	var actions := ["回首頁","↶ 復原","✕ 刪除","★ 收藏"]
	var ids := ["home","undo","delete","save"]
	var right := size.x-14.0
	for i in range(actions.size()-1,-1,-1):
		var width := 120.0 if i!=0 else 123.0
		var rect := Rect2(Vector2(right-width,10),Vector2(width-5,57))
		right -= width+6.0
		_card(rect,Color("#FFF1CC"),15)
		_text(actions[i],rect.position+Vector2(12,36),21)
		toolbar_buttons.append({"rect":rect,"action":ids[i]})
	# Keep the map completely unobstructed: move both the instruction and
	# the pinch-zoom percentage into the area just left of "回首頁".
	var message := notice
	if page == "guide" and guide_step >= guide_parts.size():
		message = "完成了！太棒了！記得按右上角的「收藏」"
	var home_left := float(toolbar_buttons[toolbar_buttons.size()-1]["rect"].position.x)
	var hint_area := _toolbar_hint_rect(home_left)
	if hint_area.size.x >= 18.0:
		var shown := _fit_toolbar_hint(message,hint_area.size.x,18)
		if not shown.is_empty():
			_text(shown,Vector2(hint_area.position.x,36),18,Color("#FFFFFF"))
		var zoom_text := _fit_toolbar_hint("雙指縮放 %d%%" % roundi(zoom_factor*100.0),hint_area.size.x,16)
		if not zoom_text.is_empty():
			_text(zoom_text,Vector2(hint_area.position.x,59),16,Color("#E5F7FF"))
	_card(board_area,Color("#FFFFFF"),22)
	var map_start := grid_origin+Vector2(canvas_bounds.position)*grid_cell
	var map_end := map_start+Vector2(canvas_bounds.size)*grid_cell
	var visible_left := maxf(board_area.position.x+5.0,map_start.x)
	var visible_right := minf(board_area.end.x-5.0,map_end.x)
	var visible_top := maxf(board_area.position.y+5.0,map_start.y)
	var visible_bottom := minf(board_area.end.y-5.0,map_end.y)
	if visible_left < visible_right and visible_top < visible_bottom:
		for x in range(canvas_bounds.position.x,canvas_bounds.end.x+1):
			var px := grid_origin.x+float(x)*grid_cell
			if px >= visible_left and px <= visible_right:
				draw_line(Vector2(px,visible_top),Vector2(px,visible_bottom),Color("#EFF3F4"),1.0)
		for y in range(canvas_bounds.position.y,canvas_bounds.end.y+1):
			var py := grid_origin.y+float(y)*grid_cell
			if py >= visible_top and py <= visible_bottom:
				draw_line(Vector2(visible_left,py),Vector2(visible_right,py),Color("#EFF3F4"),1.0)
	if page == "guide" and guide_step < guide_parts.size():
		var target: Dictionary = guide_parts[guide_step]
		var target_box := _brick_rect(target)
		_card(target_box,Color("#A6E0AF",0.37),8,Color("#3DA875"))
	for piece in pieces:
		if _brick_rect(piece).intersects(board_area.grow(-5.0)):
			_draw_brick(piece,int(piece["id"]) == selected_id)
	if (gesture == "new" or gesture == "existing") and preview_cell.x > -50:
		var kind := selected_kind
		var color_index := selected_color
		if gesture == "existing":
			var existing := _find_by_id(dragged_id)
			if not existing.is_empty():
				kind = int(existing["kind"])
				color_index = int(existing["color"])
		var rotation := selected_rotation
		if gesture == "existing":
			var moving_piece := _find_by_id(dragged_id)
			if not moving_piece.is_empty():
				rotation = Core.rotation_of(moving_piece)
		var sample := Core.make_piece(9999,kind,color_index,preview_cell,rotation)
		if _on_board(pointer_point):
			var valid := Core.can_place(pieces,sample,dragged_id if gesture=="existing" else -1)
			_card(_brick_rect(sample),Color("#90D5AB",0.35) if valid else Color("#FBAAAA",0.45),9,Color("#54B47D") if valid else Color("#DE6A6A"))
	_draw_palette()

func _draw_palette() -> void:
	var top := size.y-PALETTE_HEIGHT
	_card(Rect2(Vector2(0,top),Vector2(size.x,PALETTE_HEIGHT)),Color("#FFF2DB"),19)
	_text("積木：點兩下 ↻ 轉方向，左右滑換積木",Vector2(24,top+23),19,Color("#8A6A4B"))
	for slot in range(Core.PALETTE_KINDS.size()):
		var i: int = Core.PALETTE_KINDS[slot]
		var x := 22.0+float(slot)*SHAPE_WIDTH-shape_scroll
		var rect := Rect2(Vector2(x,top+29),Vector2(105,69))
		if rect.position.x < 6 or rect.end.x > size.x-7:
			continue
		_card(rect,Color("#FFFFFF") if i != selected_kind else Color("#FCE8B0"),14,Color("#F5BC66") if i==selected_kind else Color("#E5E0DA"))
		var shape := Core.size_for(i,int(palette_rotations.get(i,0)))
		var cell := minf(23.0, minf(81.0/float(shape.x),40.0/float(shape.y)))
		var bounds := Rect2(Vector2(x+(105-shape.x*cell)*0.5,top+36+(40-shape.y*cell)*0.5),Vector2(shape)*cell)
		_paint_brick(bounds,Core.color_for(selected_color),shape,cell,false)
		_text(Core.shape_label(i),Vector2(x+33,top+91),17,Color("#60778A"))
		if i == selected_kind and shape.x != shape.y:
			_text("↻",Vector2(x+83,top+91),19,Color("#C97733"))
	_text("顏色",Vector2(20,top+135),18,Color("#8A6A4B"))
	for i in Core.COLORS.size():
		var cx := 110.0+float(i)*COLOR_WIDTH-color_scroll+22.0
		if cx < 125 or cx > size.x-24:
			continue
		var cy := top+132.0
		draw_circle(Vector2(cx,cy),24.0,Color.WHITE if selected_color==i else Color("#D4DADD"))
		draw_circle(Vector2(cx,cy),20.0,Core.color_for(i))
		if i == selected_color:
			draw_arc(Vector2(cx,cy),26.0,0.0,TAU,32,Color("#6E789B"),3.0)

func _brick_rect(piece: Dictionary) -> Rect2:
	var cell := Core.cell_of(piece)
	var dims := Core.size_for(int(piece["kind"]),Core.rotation_of(piece))
	return Rect2(grid_origin+Vector2(cell)*grid_cell,Vector2(dims)*grid_cell)

func _draw_brick(piece: Dictionary, highlighted: bool) -> void:
	var rect := _brick_rect(piece)
	var dims := Core.size_for(int(piece["kind"]),Core.rotation_of(piece))
	_paint_brick(rect,Core.color_for(int(piece["color"])),dims,grid_cell,highlighted)

func _paint_brick(rect: Rect2, paint: Color, dims: Vector2i, single_cell: float, highlighted: bool) -> void:
	if highlighted:
		_card(rect.grow(5.0),Color("#FFD66F"),11)
	_card(Rect2(rect.position+Vector2(2.5,4.0),rect.size),paint.darkened(0.25),8)
	_card(Rect2(rect.position+Vector2(1,0),rect.size-Vector2(3,4)),paint,8)
	draw_line(rect.position+Vector2(6,4),Vector2(rect.end.x-7,rect.position.y+4),paint.lightened(0.35),3.0)
	var radius := maxf(3.2,minf(11.0,single_cell*0.17))
	for x in dims.x:
		for y in dims.y:
			var center := rect.position+Vector2((x+0.5)*single_cell,(y+0.5)*single_cell)
			draw_circle(center+Vector2(1,2),radius+1.2,paint.darkened(0.18))
			draw_circle(center,radius,paint.lightened(0.16))
			draw_circle(center-Vector2(2,2),radius*0.32,paint.lightened(0.38))

func _on_board(point: Vector2) -> bool:
	return board_area.grow(-7.0).has_point(point)

func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x-grid_origin.x)/grid_cell),floori((point.y-grid_origin.y)/grid_cell))

func _cell_centered(point: Vector2, kind: int, rotation: int = 0) -> Vector2i:
	var dims := Core.size_for(kind,rotation)
	var x := roundi((point.x-grid_origin.x)/grid_cell-float(dims.x)*0.5)
	var y := roundi((point.y-grid_origin.y)/grid_cell-float(dims.y)*0.5)
	return Vector2i(x,y)

func _hit_piece(point: Vector2) -> Dictionary:
	for i in range(pieces.size()-1,-1,-1):
		var piece: Dictionary = pieces[i]
		if _brick_rect(piece).has_point(point):
			return piece
	return {}

func _find_by_id(id: int) -> Dictionary:
	for p in pieces:
		if int(p["id"]) == id:
			return p
	return {}

func _remember() -> void:
	history.append({"pieces":pieces.duplicate(true),"step":guide_step,"next_id":next_id})
	if history.size() > 50:
		history.pop_front()
	future.clear()

func _schedule_save() -> void:
	autosave_timer.start()

func _save_now() -> void:
	if autosave_timer != null:
		autosave_timer.stop()
	Store.autosave(pieces,work_title,guide_index,guide_step,gallery_file)

func _restore(document: Dictionary) -> void:
	pieces = document.get("pieces",[]).duplicate(true)
	work_title = str(document.get("title","我的積木作品"))
	var origin := str(document.get("file",document.get("gallery_file","")))
	gallery_file = origin if Store.gallery_path_valid(origin) else ""
	next_id = 1
	for piece in pieces:
		next_id = maxi(next_id,int(piece["id"])+1)
	guide_index = int(document.get("guide_id",-1))
	guide_parts = Guides.pieces_for(guide_index) if guide_index >= 0 else []
	guide_step = clampi(int(document.get("step",0)),0,guide_parts.size())
	selected_id = -1
	history.clear()
	future.clear()
	# Reopen large works near a real brick, not an empty middle of the world.
	pan_offset = Vector2.ZERO
	if not pieces.is_empty():
		focus_cell = Core.rect_of(pieces.back()).get_center()
	else:
		focus_cell = Vector2(Core.COLUMNS*0.5,Core.ROWS*0.5)
	_refresh_canvas()

func _archive_existing() -> void:
	if pieces.is_empty():
		return
	# Gallery viewing is read-only. New works are archived once; opened works
	# overwrite their original file only when their actual bricks changed.
	var saved_path := Store.save_work(pieces,work_title,gallery_file)
	if not saved_path.is_empty():
		gallery_file = saved_path

func _start_new() -> void:
	_archive_existing()
	pieces = []
	gallery_file = ""
	next_id = 1
	selected_id = -1
	work_title = "自由創作"
	guide_index = -1
	guide_step = 0
	guide_parts = []
	selected_kind = 3
	selected_rotation = 0
	palette_rotations.clear()
	selected_color = 0
	history.clear()
	future.clear()
	page = "play"
	notice = "從下面抓一塊積木，往上滑就能放囉！"
	_refresh_canvas()
	_schedule_save()
	queue_redraw()

func _continue() -> void:
	page = "guide" if guide_index >= 0 and guide_step < guide_parts.size() else "play"
	notice = "滑動積木就能搬家，左右滑下方積木找更多！"
	queue_redraw()

func _start_guide(index: int) -> void:
	var guide := Guides.pieces_for(index)
	if guide.is_empty():
		return
	_archive_existing()
	pieces = []
	gallery_file = ""
	next_id = 1
	selected_id = -1
	guide_index = index
	guide_step = 0
	guide_parts = guide
	work_title = Guides.NAMES[index]
	history.clear()
	future.clear()
	_set_next_guide_piece()
	page = "guide"
	_refresh_canvas()
	_schedule_save()
	queue_redraw()

func _set_next_guide_piece() -> void:
	if guide_step >= guide_parts.size():
		notice = "好棒！作品完成了！"
		return
	var part: Dictionary = guide_parts[guide_step]
	selected_kind = Core.canonical_kind(int(part["kind"]))
	selected_rotation = Core.canonical_rotation(int(part["kind"])) ^ Core.rotation_of(part)
	palette_rotations[selected_kind] = selected_rotation
	selected_color = int(part["color"])
	notice = "第 %d / %d 塊：點兩下可轉方向，再滑進框框" % [guide_step+1,guide_parts.size()]

func _perform(action: String) -> void:
	match action:
		"home":
			_save_now()
			page = "home"
		"new":
			_start_new()
		"continue":
			_continue()
		"guides":
			page = "guides"
		"gallery":
			# Listing a collection must never perform an implicit Save As.
			page = "gallery"
		"undo":
			_undo()
		"delete":
			_delete_selected()
		"save":
			_save_gallery()
		_:
			if action.begins_with("guide:"):
				_start_guide(int(action.get_slice(":",1)))
			elif action.begins_with("gallery:"):
				var list := Store.list_gallery()
				var index := int(action.get_slice(":",1))
				if index >= 0 and index < list.size():
					_archive_existing()
					_restore(list[index])
					_continue()
	queue_redraw()

func _undo() -> void:
	if history.is_empty():
		notice = "已經是最早的一步囉"
		return
	future.append({"pieces":pieces.duplicate(true),"step":guide_step,"next_id":next_id})
	var old: Dictionary = history.pop_back()
	pieces = old["pieces"]
	guide_step = int(old["step"])
	next_id = int(old["next_id"])
	if guide_index >= 0:
		_set_next_guide_piece()
	selected_id = -1
	notice = "已經退回上一步"
	_refresh_canvas()
	_schedule_save()

func _delete_selected() -> void:
	if selected_id < 0 or page == "guide":
		notice = "先點一下要刪除的積木"
		return
	_remember()
	var remaining: Array = []
	for part in pieces:
		if int(part["id"]) != selected_id:
			remaining.append(part)
	pieces = remaining
	selected_id = -1
	notice = "積木收起來了"
	_refresh_canvas()
	_schedule_save()

func _save_gallery() -> void:
	if pieces.is_empty():
		notice = "先玩幾塊積木再收藏吧"
		return
	var saved_path := Store.save_work(pieces,work_title,gallery_file)
	if not saved_path.is_empty():
		gallery_file = saved_path
		_save_now()
		notice = "作品已收藏！再次收藏會更新同一份 ★"
	else:
		notice = "收藏失敗，請檢查儲存空間"

func _drop_new(point: Vector2) -> void:
	if not _on_board(point):
		return
	if page == "guide":
		if guide_step >= guide_parts.size():
			return
		var target: Dictionary = guide_parts[guide_step]
		if Core.canonical_kind(selected_kind) != Core.canonical_kind(int(target["kind"])):
			notice = "找出跟亮亮框框一樣的積木"
			return
		if Core.size_for(selected_kind,selected_rotation) != Core.size_for(int(target["kind"]),Core.rotation_of(target)):
			notice = "點兩下積木，轉成跟亮亮框框一樣的方向"
			return
		var midpoint := _brick_rect(target).get_center()
		if point.distance_to(midpoint) > grid_cell*3.5:
			notice = "再滑近一點亮亮的框框"
			return
		var to_place := Core.make_piece(next_id,selected_kind,selected_color,Core.cell_of(target),selected_rotation)
		if not Core.can_place(pieces,to_place):
			notice = "這裡已經有積木了"
			return
		_remember()
		pieces.append(to_place)
		next_id += 1
		guide_step += 1
		_set_next_guide_piece()
		if guide_step >= guide_parts.size():
			notice = "完成囉！按右上角「收藏」"
		_refresh_canvas(Core.rect_of(to_place).get_center())
		_schedule_save()
	else:
		var new_piece := Core.make_piece(next_id,selected_kind,selected_color,_cell_centered(point,selected_kind,selected_rotation),selected_rotation)
		if not Core.can_place(pieces,new_piece):
			notice = "那裡放不下，找個空白地方試試"
			return
		_remember()
		pieces.append(new_piece)
		next_id += 1
		selected_id = int(new_piece["id"])
		notice = "好棒！底圖會跟著積木一起變大！"
		_refresh_canvas(Core.rect_of(new_piece).get_center())
		_schedule_save()

func _drop_existing(point: Vector2) -> void:
	if not _on_board(point) or dragged_id < 0:
		return
	var piece := _find_by_id(dragged_id)
	if piece.is_empty():
		return
	var shift := Vector2i(roundi((point.x-start_point.x)/grid_cell),roundi((point.y-start_point.y)/grid_cell))
	if shift == Vector2i.ZERO:
		selected_id = dragged_id
		notice = "選好了！點下面的顏色就能換色"
		return
	var moved: Dictionary = piece.duplicate(true)
	moved["x"] = drag_start_cell.x+shift.x
	moved["y"] = drag_start_cell.y+shift.y
	if not Core.can_place(pieces,moved,dragged_id):
		notice = "這裡放不下，積木留在原位"
		return
	_remember()
	for index in pieces.size():
		if int(pieces[index]["id"]) == dragged_id:
			pieces[index] = moved
			break
	selected_id = dragged_id
	notice = "積木搬好家了"
	_refresh_canvas(Core.rect_of(moved).get_center())
	_schedule_save()

func _pick_shape(point: Vector2) -> int:
	if point.y < size.y-PALETTE_HEIGHT+27 or point.y > size.y-PALETTE_HEIGHT+104:
		return -1
	var slot := floori((point.x-22.0+shape_scroll)/SHAPE_WIDTH)
	if slot < 0 or slot >= Core.PALETTE_KINDS.size():
		return -1
	return Core.PALETTE_KINDS[slot]

func _pick_color(point: Vector2) -> int:
	var index := roundi((point.x-132.0+color_scroll)/COLOR_WIDTH)
	if index < 0 or index >= Core.COLORS.size():
		return -1
	var x := 132.0+float(index)*COLOR_WIDTH-color_scroll
	if absf(point.x-x) > 30.0:
		return -1
	return index

func _register_double_tap(target: String, point: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	var doubled := target == last_tap_target and now-last_tap_time <= DOUBLE_TAP_MSEC and point.distance_to(last_tap_position) <= 34.0
	last_tap_target = "" if doubled else target
	last_tap_time = now
	last_tap_position = point
	return doubled

func _rotate_existing(piece_id: int) -> void:
	var original := _find_by_id(piece_id)
	if original.is_empty():
		return
	var dims := Core.size_for(int(original["kind"]))
	if dims.x == dims.y:
		notice = "正方形不需要轉方向喔"
		return
	var turned := Core.turned_piece(original,pieces)
	if turned.is_empty():
		notice = "旁邊太擠了，換個空位再轉看看"
		return
	_remember()
	for index in pieces.size():
		if int(pieces[index]["id"]) == piece_id:
			pieces[index] = turned
			break
	selected_id = piece_id
	notice = "轉好了！點兩下可以再轉回來"
	_refresh_canvas(Core.rect_of(turned).get_center())
	_schedule_save()

func _rotate_palette(kind: int) -> void:
	var dims := Core.size_for(kind)
	if dims.x == dims.y:
		notice = "正方形的方向都是一樣的"
		return
	selected_kind = kind
	selected_rotation = 1-int(palette_rotations.get(kind,0))
	palette_rotations[kind] = selected_rotation
	notice = "轉好了，往上滑就能放囉！"

func _pointer_down(point: Vector2) -> void:
	pressed = true
	start_point = point
	last_point = point
	pointer_point = point
	gesture = ""
	dragged_id = -1
	pressed_shape = -1
	pressed_color = -1
	preview_cell = Vector2i(-100,-100)
	if page == "home" or page == "guides" or page == "gallery":
		gesture = "menu"
	elif point.y <= TOP_HEIGHT:
		gesture = "toolbar"
	elif point.y >= size.y-67:
		gesture = "color"
		pressed_color = _pick_color(point)
	elif point.y >= size.y-PALETTE_HEIGHT:
		gesture = "shape"
		pressed_shape = _pick_shape(point)
	elif _on_board(point):
		var hit := _hit_piece(point)
		if not hit.is_empty():
			gesture = "existing"
			dragged_id = int(hit["id"])
			drag_start_cell = Core.cell_of(hit)
			selected_id = dragged_id
		else:
			gesture = "blank"
	queue_redraw()

func _pointer_move(point: Vector2) -> void:
	if not pressed:
		return
	var delta := point-last_point
	pointer_point = point
	var total := point-start_point
	if gesture == "blank" and total.length() > TAP_MAX_MOVE:
		gesture = "pan"
		last_tap_target = ""
	if gesture == "pan":
		pan_offset += delta
		_layout()
	if gesture == "shape" and pressed_shape >= 0:
		if point.y < size.y-PALETTE_HEIGHT-12 and total.y < -24:
			gesture = "new"
			selected_kind = pressed_shape
			selected_rotation = int(palette_rotations.get(selected_kind,0))
			preview_cell = _cell_centered(point,selected_kind,selected_rotation)
		elif absf(total.x)>20 and absf(total.x)>absf(total.y)*1.2:
			gesture = "shape_scroll"
			last_tap_target = ""
	if gesture == "shape_scroll":
		shape_scroll = clampf(shape_scroll-delta.x,0.0,maxf(0,Core.PALETTE_KINDS.size()*SHAPE_WIDTH-(size.x-40)))
	elif gesture == "color" and absf(total.x)>20:
		gesture = "color_scroll"
		last_tap_target = ""
	if gesture == "color_scroll":
		color_scroll = clampf(color_scroll-delta.x,0.0,maxf(0,Core.COLORS.size()*COLOR_WIDTH-(size.x-130)))
	elif gesture == "new":
		preview_cell = _cell_centered(point,selected_kind,selected_rotation)
	elif gesture == "existing":
		var movement := Vector2i(roundi(total.x/grid_cell),roundi(total.y/grid_cell))
		preview_cell = drag_start_cell+movement
	last_point = point
	queue_redraw()

func _pointer_up(point: Vector2) -> void:
	if not pressed:
		return
	pointer_point = point
	var travel := start_point.distance_to(point)
	var old_gesture := gesture
	pressed = false
	gesture = ""
	preview_cell = Vector2i(-100,-100)
	if old_gesture == "menu" and travel < 26.0:
		for btn in menu_buttons:
			if btn["rect"].has_point(start_point) and btn["rect"].has_point(point):
				_perform(str(btn["action"]))
				break
	elif old_gesture == "toolbar" and travel < 30.0:
		for btn in toolbar_buttons:
			if btn["rect"].has_point(start_point) and btn["rect"].has_point(point):
				_perform(str(btn["action"]))
				break
	elif old_gesture == "shape" and travel < TAP_MAX_MOVE and pressed_shape >= 0:
		selected_kind = pressed_shape
		selected_rotation = int(palette_rotations.get(selected_kind,0))
		selected_id = -1
		if _register_double_tap("shape:%d" % selected_kind,point):
			_rotate_palette(selected_kind)
		else:
			notice = "選好了！點兩下可轉方向，再往上滑"
	elif old_gesture == "color" and travel < 25.0 and pressed_color >= 0:
		selected_color = pressed_color
		if selected_id >= 0 and page == "play":
			for i in pieces.size():
				if int(pieces[i]["id"]) == selected_id:
					_remember()
					pieces[i]["color"] = selected_color
					_schedule_save()
					break
		notice = "顏色換好了"
	elif old_gesture == "new" and _on_board(point):
		last_tap_target = ""
		_drop_new(point)
	elif old_gesture == "existing":
		if travel <= TAP_MAX_MOVE and dragged_id >= 0 and _register_double_tap("brick:%d" % dragged_id,point):
			_rotate_existing(dragged_id)
		else:
			if travel > TAP_MAX_MOVE:
				last_tap_target = ""
			_drop_existing(point)
	elif old_gesture == "blank" and travel < 25.0:
		_drop_new(point)
	elif old_gesture == "pan":
		notice = "滑動空白底圖就能移動地圖"
	dragged_id = -1
	queue_redraw()

func _touch_points() -> Array:
	return touch_positions.values()

func _start_pinch() -> void:
	# Cancel any unfinished one-finger action. Never place, move, recolor or
	# rotate a brick as a side effect of adding or lifting the second finger.
	pinch_locked = true
	pressed = false
	gesture = ""
	dragged_id = -1
	pressed_shape = -1
	pressed_color = -1
	preview_cell = Vector2i(-100,-100)
	last_tap_target = ""
	var positions := _touch_points()
	if positions.size() < 2:
		return
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	var middle := (a+b)*0.5
	pinch_active = (page == "play" or page == "guide") and board_area.has_point(a) and board_area.has_point(b)
	if not pinch_active:
		queue_redraw()
		return
	pinch_begin_distance = maxf(20.0,a.distance_to(b))
	pinch_begin_zoom = zoom_factor
	pinch_anchor_cell = (middle-grid_origin)/grid_cell
	queue_redraw()

func _update_pinch() -> void:
	if not pinch_active or touch_positions.size() < 2:
		return
	var positions := _touch_points()
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	var center := (a+b)*0.5
	var ratio := maxf(1.0,a.distance_to(b))/pinch_begin_distance
	zoom_factor = clampf(pinch_begin_zoom*ratio,MIN_ZOOM,MAX_ZOOM)
	_layout()
	# Keep the logical point between the fingers in roughly the same place.
	# This also follows two fingers moved together, acting as a pan gesture.
	pan_offset += center-(grid_origin+pinch_anchor_cell*grid_cell)
	_layout()
	queue_redraw()

func _touch_begin(index: int, point: Vector2) -> void:
	touch_positions[index] = point
	touch_active = true
	if touch_positions.size() == 1 and not pinch_locked:
		_pointer_down(point)
	elif touch_positions.size() >= 2 and not pinch_locked:
		_start_pinch()
	queue_redraw()

func _touch_dragged(index: int, point: Vector2) -> void:
	if not touch_positions.has(index):
		return
	touch_positions[index] = point
	if pinch_locked:
		_update_pinch()
	elif touch_positions.size() == 1:
		_pointer_move(point)

func _touch_end(index: int, point: Vector2) -> void:
	if not touch_positions.has(index):
		return
	touch_positions.erase(index)
	if pinch_locked:
		if touch_positions.size() < 2:
			pinch_active = false
		if touch_positions.is_empty():
			pinch_locked = false
			notice = "雙指縮放完成，還可以繼續滑積木！"
	else:
		if touch_positions.is_empty():
			_pointer_up(point)
	touch_active = not touch_positions.is_empty()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		last_touch_msec = Time.get_ticks_msec()
		if event.pressed:
			_touch_begin(event.index,event.position)
		else:
			_touch_end(event.index,event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		last_touch_msec = Time.get_ticks_msec()
		_touch_dragged(event.index,event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not touch_active and not pinch_locked and Time.get_ticks_msec()-last_touch_msec > 550:
		if event.pressed:
			_pointer_down(event.position)
		else:
			_pointer_up(event.position)
		accept_event()
	elif event is InputEventMouseMotion and pressed and not touch_active and not pinch_locked and Time.get_ticks_msec()-last_touch_msec > 550:
		_pointer_move(event.position)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
