extends Control
class_name GenePoolView

signal gene_clicked(kind: String, index_in_pool: int, mouse_button: int)

@export var radius: float = 8.0
@export var gap: float = 6.0
@export var border_color: Color = Color(0,0,0,0.6)
@export var hover_border: Color = Color(1,1,1,0.9)
@export var selected_border: Color = Color(1,1,0.4,1.0)
@export var bg: Color = Color(0,0,0,0)

var _pool: Array[String] = []
var _rects: Array[Rect2] = []
var _kinds: Array[String] = []
var _hover_idx: int = -1
var _selected_idx: int = -1
var _counts: Dictionary = {}
var _color_provider: Callable



func set_color_provider(cb: Callable) -> void:
	_color_provider = cb

func set_pool(pool: Array[String]) -> void:
	_pool = pool.duplicate()
	_counts.clear()
	for k in _pool:
		_counts[k] = _counts.get(k, 0) + 1
	_kinds = _pool.duplicate()
	_layout_circles()
	queue_redraw()

func _layout_circles() -> void:
	_rects.clear()
	var d: float = radius * 2.0
	var step: float = d + gap
	var x := gap
	var y := gap
	var max_w: float = size.x
	if max_w <= 0.0:
		max_w = 300.0
	for i in _pool.size():
		if x + d + gap > max_w:
			x = gap
			y += step
		_rects.append(Rect2(Vector2(x, y), Vector2(d, d)))
		x += step
	# スクロール用に高さを設定
	custom_minimum_size = Vector2(max_w, y + d + gap)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_circles()

func _draw() -> void:
	if bg.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), bg)
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		var center := r.position + r.size * 0.5
		var kind := _kinds[i]
		var fill := Color(0.8,0.82,0.9)
		if _color_provider.is_valid():
			fill = _color_provider.call(kind)
		draw_circle(center, radius, fill)
		var bc := border_color
		if i == _selected_idx:
			bc = selected_border
		elif i == _hover_idx:
			bc = hover_border
		draw_arc(center, radius, 0, TAU, 32, bc, 2.0)

	if _hover_idx >= 0:
		var k := _kinds[_hover_idx]
		var n := int(_counts.get(k, 0))
		var pct := 0.0
		if _pool.size() > 0:
			pct = float(n) / float(_pool.size()) * 100.0
		var label := "%s  x%d  (%.1f%%)" % [k, n, pct]
		var pos := get_local_mouse_position() + Vector2(12, 12)
		var pad := Vector2(6, 4)
		var font := get_theme_default_font()
		var font_size := get_theme_default_font_size()
		var text_size := font.get_string_size(label, font_size)
		var rect := Rect2(pos - pad, text_size + pad * 2.0)
		draw_rect(rect, Color(0,0,0,0.7))
		draw_string(font, pos + Vector2(0, font_size * 0.8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1,1,1,0.95))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_idx = _hit_index(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var mbe := event as InputEventMouseButton
		var idx := _hit_index(mbe.position)
		if idx >= 0:
			_selected_idx = idx
			queue_redraw()
			var kind := _kinds[idx]
			emit_signal("gene_clicked", kind, idx, mbe.button_index)

func _hit_index(p: Vector2) -> int:
	for i in range(_rects.size()):
		if _rects[i].has_point(p):
			var c := _rects[i].position + _rects[i].size * 0.5
			if c.distance_to(p) <= radius + 1.0:
				return i
	return -1
