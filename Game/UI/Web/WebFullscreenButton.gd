extends Button

@export var web_only := true
@export var button_text := "Fullscreen"

func _ready() -> void:
	text = button_text
	_apply_default_style()
	visible = not web_only or OS.has_feature("web")
	focus_mode = Control.FOCUS_NONE

	if not pressed.is_connected(_request_browser_fullscreen):
		pressed.connect(_request_browser_fullscreen)

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
