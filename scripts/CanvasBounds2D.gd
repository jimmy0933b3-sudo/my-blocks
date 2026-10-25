extends RefCounted
## Automatically expand the logical building mat whenever pieces near an edge.
## The mat begins with the old 18x9 grid so existing coordinates are preserved.
const Core = preload("res://scripts/Blocks2D.gd")
const GROW_X := 6
const GROW_Y := 3
const MARGIN := 2
const MIN_TOUCH_CELL := 28.0

static func initial_bounds() -> Rect2i:
	return Rect2i(0,0,Core.COLUMNS,Core.ROWS)

static func bounds_for(pieces: Array) -> Rect2i:
	var left := 0
	var top := 0
	var right := Core.COLUMNS
	var bottom := Core.ROWS
	for piece in pieces:
		var rectangle := Core.rect_of(piece)
		var wanted_left := rectangle.position.x-MARGIN
		var wanted_top := rectangle.position.y-MARGIN
		var wanted_right := rectangle.end.x+MARGIN
		var wanted_bottom := rectangle.end.y+MARGIN
		while wanted_left < left:
			left -= GROW_X
		while wanted_top < top:
			top -= GROW_Y
		while wanted_right > right:
			right += GROW_X
		while wanted_bottom > bottom:
			bottom += GROW_Y
	return Rect2i(left,top,right-left,bottom-top)

static func fit_cell(available: Vector2, bounds: Rect2i) -> float:
	var width := maxf(1.0,float(bounds.size.x))
	var height := maxf(1.0,float(bounds.size.y))
	var natural := floorf(minf((available.x-28.0)/width,(available.y-22.0)/height))
	return clampf(natural,MIN_TOUCH_CELL,60.0)

static func fully_visible(available: Vector2, bounds: Rect2i, cell: float) -> bool:
	return float(bounds.size.x)*cell <= available.x-12.0 and float(bounds.size.y)*cell <= available.y-12.0
