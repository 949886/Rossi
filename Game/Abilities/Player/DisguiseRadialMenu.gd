extends Control
class_name DisguiseRadialMenu

const BASE_COLOR := Color(0.12, 0.15, 0.19, 0.82)
const HIGHLIGHT_COLOR := Color(0.29, 0.8, 0.94, 0.92)
const ACTIVE_COLOR := Color(0.98, 0.75, 0.33, 0.96)
const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.18)

@export_range(60.0, 220.0, 1.0) var inner_radius := 52.0
@export_range(100.0, 320.0, 1.0) var outer_radius := 138.0
@export_range(0.0, 40.0, 1.0) var label_radius_padding := 34.0

var _ability: DisguiseAbility
var _label_nodes: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_ability(ability: DisguiseAbility) -> void:
	if _ability == ability:
		return
	_ability = ability
	_rebuild_labels()
	queue_redraw()


func _process(_delta: float) -> void:
	if _ability == null or not _ability.is_menu_open:
		return
	_update_hover_selection()
	_layout_labels()
	queue_redraw()


func _draw() -> void:
	if _ability == null or not _ability.is_menu_open:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.42), true)

	var profiles := _ability.get_profiles()
	if profiles.is_empty():
		return

	var center := size * 0.5
	var count := profiles.size()
	var angle_step := TAU / float(count)
	var start_angle := -PI * 0.5
	var active_profile := _ability.get_current_profile()

	for index in range(count):
		var profile := profiles[index]
		var segment_start := start_angle + angle_step * index
		var segment_end := segment_start + angle_step
		var fill_color := BASE_COLOR
		if index == _ability.get_selected_index():
			fill_color = HIGHLIGHT_COLOR
		elif active_profile == profile:
			fill_color = ACTIVE_COLOR

		var points := _build_ring_segment(center, inner_radius, outer_radius, segment_start, segment_end, 24)
		draw_colored_polygon(points, fill_color)
		_draw_ring_segment_outline(center, inner_radius, outer_radius, segment_start, segment_end)

	draw_circle(center, inner_radius - 8.0, Color(0.05, 0.07, 0.09, 0.9))
	draw_arc(center, inner_radius - 8.0, 0.0, TAU, 64, OUTLINE_COLOR, 2.0, true)


func _update_hover_selection() -> void:
	var profiles := _ability.get_profiles()
	if profiles.is_empty():
		return

	var center := get_viewport_rect().size * 0.5
	var pointer := get_viewport().get_mouse_position()
	var delta := pointer - center
	if delta.length() < inner_radius * 0.45:
		return

	var angle := wrapf(delta.angle() + PI * 0.5, 0.0, TAU)
	var angle_step := TAU / float(profiles.size())
	var index := int(floor(angle / angle_step))
	_ability.set_selected_index(index)


func _rebuild_labels() -> void:
	for label_node in _label_nodes:
		if is_instance_valid(label_node):
			label_node.queue_free()
	_label_nodes.clear()

	if _ability == null:
		return

	for profile in _ability.get_profiles():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(110.0, 42.0)
		label.text = profile.display_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_label_nodes.append(label)

	_layout_labels()


func _layout_labels() -> void:
	if _ability == null:
		return

	var profiles := _ability.get_profiles()
	if profiles.is_empty():
		return

	var center := size * 0.5
	var count := profiles.size()
	var angle_step := TAU / float(count)
	var start_angle := -PI * 0.5
	var label_radius := outer_radius + label_radius_padding
	var active_profile := _ability.get_current_profile()

	for index in range(mini(_label_nodes.size(), profiles.size())):
		var profile := profiles[index]
		var label := _label_nodes[index]
		var angle := start_angle + angle_step * (float(index) + 0.5)
		var label_center := center + Vector2.RIGHT.rotated(angle) * label_radius
		label.position = label_center - label.size * 0.5
		if index == _ability.get_selected_index():
			label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif active_profile == profile:
			label.modulate = ACTIVE_COLOR
		else:
			label.modulate = Color(0.86, 0.9, 0.96, 0.82)


func _build_ring_segment(center: Vector2, inner_r: float, outer_r: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2.RIGHT.rotated(angle) * outer_r)
	for step in range(steps, -1, -1):
		var t := float(step) / float(steps)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2.RIGHT.rotated(angle) * inner_r)
	return points


func _draw_ring_segment_outline(center: Vector2, inner_r: float, outer_r: float, start_angle: float, end_angle: float) -> void:
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	var steps := 24
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var angle := lerpf(start_angle, end_angle, t)
		outer_points.append(center + Vector2.RIGHT.rotated(angle) * outer_r)
		inner_points.append(center + Vector2.RIGHT.rotated(angle) * inner_r)
	draw_polyline(outer_points, OUTLINE_COLOR, 2.0, true)
	draw_polyline(inner_points, OUTLINE_COLOR, 2.0, true)
	draw_line(inner_points[0], outer_points[0], OUTLINE_COLOR, 2.0, true)
	draw_line(inner_points[inner_points.size() - 1], outer_points[outer_points.size() - 1], OUTLINE_COLOR, 2.0, true)
