extends Control
const UI = preload("res://ui_style.gd")
var graph: Dictionary = {}
var cards: Dictionary = {}

func layout_cards() -> void:
	for item in graph.get("nodes", []):
		var card: Control = cards[item.id]
		card.size = Vector2(200, 36) if item.get("kind", "topic") == "group" else Vector2(204, 82)
		card.position = Vector2(item.position[0], item.position[1]) - card.size * 0.5
	queue_redraw()

func edge_points(edge: Dictionary) -> PackedVector2Array:
	var source: Rect2 = cards[edge.from].get_rect()
	var target: Rect2 = cards[edge.to].get_rect()
	var a := Vector2(source.get_center().x, source.end.y + 3)
	var b := Vector2(target.get_center().x, target.position.y - 5)
	if edge.has("route"):
		var points := PackedVector2Array()
		for p in edge.route: points.append(Vector2(p[0], p[1]))
		return points
	if is_equal_approx(source.get_center().y, target.get_center().y):
		var direction := signf(target.get_center().x - source.get_center().x)
		a = Vector2(source.get_center().x + direction * (source.size.x / 2 + 3), source.get_center().y)
		b = Vector2(target.get_center().x - direction * (target.size.x / 2 + 5), target.get_center().y)
		return PackedVector2Array([a,b])
	var middle := (a.y + b.y) * 0.5
	return PackedVector2Array([a, Vector2(a.x,middle), Vector2(b.x,middle), b])

func _draw() -> void:
	var heads: Dictionary = {}
	for group in graph.get("groups", []):
		var box := Rect2(group.rect[0], group.rect[1], group.rect[2], group.rect[3])
		draw_style_box(UI.card("101f2b", "2b414f", 10), box)
	for edge in graph.get("edges", []):
		var points := edge_points(edge)
		var recommended: bool = edge.get("kind", "required") == "recommended"
		var color := Color("62786f") if recommended else Color("688da2")
		if recommended: draw_dashes(points, color)
		else: draw_polyline(points, color, 1.5, true)
		var b := points[-1]
		var direction := (b - points[-2]).normalized()
		var head_key := [b,direction,recommended]
		if heads.has(head_key): continue
		heads[head_key] = true
		var side := Vector2(-direction.y, direction.x) * 4
		draw_line(b, b - direction * 8 + side, color, 1.5, true)
		draw_line(b, b - direction * 8 - side, color, 1.5, true)

func draw_dashes(points: PackedVector2Array, color: Color) -> void:
	var distance := 0.0
	for i in range(1, points.size()):
		var a := points[i-1]
		var b := points[i]
		var length := a.distance_to(b)
		var direction := (b - a).normalized()
		var cursor := 0.0
		while cursor < length:
			var phase := fmod(distance + cursor, 13.0)
			var amount := minf(length - cursor, (8.0 if phase < 8.0 else 13.0) - phase)
			if amount < 0.001: amount = minf(0.001, length - cursor)
			if phase < 8.0: draw_line(a + direction * cursor, a + direction * (cursor + amount), color, 1.3, true)
			cursor += amount
		distance += length
