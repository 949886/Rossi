extends Button

@export var web_only := true
@export var icon_color := Color(1, 1, 1, 1)
@export var icon_margin := 11.0
@export var icon_stroke_width := 3.0
@export var arrow_head_size := 10.0

var _is_browser_fullscreen := false

func _ready() -> void:
	text = ""
	_apply_default_style()
	visible = not web_only or OS.has_feature("web")
	focus_mode = Control.FOCUS_NONE
	_update_fullscreen_state()
	set_process(OS.has_feature("web"))

	if not pressed.is_connected(_request_browser_fullscreen):
		pressed.connect(_request_browser_fullscreen)
	if not mouse_entered.is_connected(queue_redraw):
		mouse_entered.connect(queue_redraw)
	if not mouse_exited.is_connected(queue_redraw):
		mouse_exited.connect(queue_redraw)
	if not button_down.is_connected(queue_redraw):
		button_down.connect(queue_redraw)
	if not button_up.is_connected(queue_redraw):
		button_up.connect(queue_redraw)

func _apply_default_style() -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0.55)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(10)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.12, 0.12, 0.12, 0.7)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)

	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _draw() -> void:
	var rect := get_rect()
	var center := rect.size / 2.0
	var left := icon_margin
	var right := rect.size.x - icon_margin
	var top := icon_margin
	var bottom := rect.size.y - icon_margin

	if _is_browser_fullscreen:
		_draw_arrow(Vector2(left, top), Vector2(center.x - 4.0, center.y - 4.0), Vector2.LEFT, Vector2.UP)
		_draw_arrow(Vector2(right, top), Vector2(center.x + 4.0, center.y - 4.0), Vector2.RIGHT, Vector2.UP)
		_draw_arrow(Vector2(left, bottom), Vector2(center.x - 4.0, center.y + 4.0), Vector2.LEFT, Vector2.DOWN)
		_draw_arrow(Vector2(right, bottom), Vector2(center.x + 4.0, center.y + 4.0), Vector2.RIGHT, Vector2.DOWN)
	else:
		_draw_arrow(Vector2(center.x - 4.0, center.y - 4.0), Vector2(left, top), Vector2.RIGHT, Vector2.DOWN)
		_draw_arrow(Vector2(center.x + 4.0, center.y - 4.0), Vector2(right, top), Vector2.LEFT, Vector2.DOWN)
		_draw_arrow(Vector2(center.x - 4.0, center.y + 4.0), Vector2(left, bottom), Vector2.RIGHT, Vector2.UP)
		_draw_arrow(Vector2(center.x + 4.0, center.y + 4.0), Vector2(right, bottom), Vector2.LEFT, Vector2.UP)

func _draw_arrow(start: Vector2, corner: Vector2, head_dir_a: Vector2, head_dir_b: Vector2) -> void:
	draw_line(start, corner, icon_color, icon_stroke_width, true)
	draw_line(corner, corner + head_dir_a * arrow_head_size, icon_color, icon_stroke_width, true)
	draw_line(corner, corner + head_dir_b * arrow_head_size, icon_color, icon_stroke_width, true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return

	if Engine.get_process_frames() % 15 == 0:
		_update_fullscreen_state()

func _update_fullscreen_state() -> void:
	if not OS.has_feature("web"):
		if _is_browser_fullscreen:
			_is_browser_fullscreen = false
			queue_redraw()
		return

	var result = JavaScriptBridge.eval("Boolean(document.fullscreenElement)", true)
	var is_fullscreen := bool(result)
	if is_fullscreen != _is_browser_fullscreen:
		_is_browser_fullscreen = is_fullscreen
		queue_redraw()

func _request_browser_fullscreen() -> void:
	if web_only and not OS.has_feature("web"):
		return

	release_focus()

	JavaScriptBridge.eval("""
		(() => {
			const root = document.documentElement;
			if (!document.fullscreenElement) {
				if (root.requestFullscreen) {
					root.requestFullscreen();
				}
				return true;
			}
			if (document.exitFullscreen) {
				document.exitFullscreen();
			}
			return false;
		})()
	""", true)
	await get_tree().process_frame
	_update_fullscreen_state()
