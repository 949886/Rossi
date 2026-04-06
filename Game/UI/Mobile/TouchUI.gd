class_name TouchUI
extends CanvasLayer

enum VisibilityMode {
	AUTO_MOBILE_ONLY,
	ALWAYS_SHOW,
	ALWAYS_HIDE,
}

@export var visibility_mode := VisibilityMode.AUTO_MOBILE_ONLY
@export var touch_controls_path: NodePath = ^"TouchControls"

var _touch_controls: Control

func _ready() -> void:
	_touch_controls = get_node_or_null(touch_controls_path) as Control
	apply_visibility_mode()

func apply_visibility_mode() -> void:
	set_touch_ui_visible(_should_show_touch_ui())

func set_touch_ui_visible(should_show: bool) -> void:
	if _touch_controls != null:
		_touch_controls.visible = should_show

	visible = should_show

func toggle_touch_ui() -> void:
	set_touch_ui_visible(not is_touch_ui_visible())

func is_touch_ui_visible() -> bool:
	return visible

func _should_show_touch_ui() -> bool:
	match visibility_mode:
		VisibilityMode.ALWAYS_SHOW:
			return true
		VisibilityMode.ALWAYS_HIDE:
			return false
		_:
			return PlatformUtils.is_mobile_platform()
