extends CanvasLayer
class_name QuestJournalPanel

const TAB_ACTIVE := 0
const TAB_COMPLETED := 1

@export var quest_controller_path: NodePath
@export var list_entry_scene: PackedScene
@export var reward_entry_scene: PackedScene
@export var toggle_action := "quest_journal"
@export var open_by_default := false

@onready var _root: Control = $Root
@onready var _header_title: Label = $Root/MainShell/MainVBox/HeaderBar/HeaderTitle
@onready var _active_button: Button = $Root/MainShell/MainVBox/HeaderBar/ActiveButton
@onready var _tracking_label: Label = $Root/MainShell/MainVBox/HeaderBar/TrackingLabel
@onready var _completed_button: Button = $Root/MainShell/MainVBox/HeaderBar/CompletedButton
@onready var _close_button: Button = $Root/MainShell/MainVBox/HeaderBar/CloseButton
@onready var _group_title: Label = $Root/MainShell/MainVBox/Body/LeftPane/LeftMargin/LeftVBox/GroupTitle
@onready var _list_container: VBoxContainer = $Root/MainShell/MainVBox/Body/LeftPane/LeftMargin/LeftVBox/QuestListScroll/QuestList
@onready var _empty_list_label: Label = $Root/MainShell/MainVBox/Body/LeftPane/LeftMargin/LeftVBox/QuestListScroll/QuestList/EmptyLabel
@onready var _title_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/Title
@onready var _meta_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/Meta
@onready var _objective_focus_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/ObjectiveBanner/ObjectiveBannerMargin/ObjectiveFocus
@onready var _summary_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/Summary
@onready var _objective_list: VBoxContainer = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/ObjectivePanel/ObjectiveMargin/ObjectiveVBox/ObjectiveList
@onready var _reward_title_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel/FooterMargin/FooterVBox/RewardRow/RewardTitle
@onready var _reward_list: HBoxContainer = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel/FooterMargin/FooterVBox/RewardRow/RewardList
@onready var _empty_rewards_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel/FooterMargin/FooterVBox/RewardRow/EmptyRewards
@onready var _status_pill_panel: PanelContainer = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel/FooterMargin/FooterVBox/StatusRow/StatusPillPanel
@onready var _status_pill: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel/FooterMargin/FooterVBox/StatusRow/StatusPillPanel/StatusPill
@onready var _controls_label: Label = $Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel/FooterMargin/FooterVBox/StatusRow/ControlsLabel

var _quest_controller: QuestLogController
var _tab := TAB_ACTIVE


func _ready() -> void:
	layer = 18
	visible = true
	_root.visible = open_by_default
	_set_ui_block_state(_root.visible)
	_style_shell()
	_resolve_controller()

	_active_button.pressed.connect(_on_active_tab_pressed)
	_completed_button.pressed.connect(_on_completed_tab_pressed)
	_close_button.pressed.connect(_hide_panel)

	_controls_label.text = "J close menu   |   Esc back   |   Up/Down change selection"
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		_set_panel_visible(not _root.visible)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_set_ui_block_state(false)


func _set_panel_visible(is_visible: bool) -> void:
	_root.visible = is_visible
	_set_ui_block_state(is_visible)
	if is_visible:
		_refresh()


func _set_ui_block_state(is_blocking: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.set_meta("quest_ui_open", is_blocking)


func _resolve_controller() -> void:
	_quest_controller = get_node_or_null(quest_controller_path) as QuestLogController
	if _quest_controller == null and not quest_controller_path.is_empty():
		return
	if _quest_controller == null:
		_quest_controller = get_parent().get_node_or_null("QuestLogController") as QuestLogController
	if _quest_controller == null:
		return

	if not _quest_controller.quest_log_changed.is_connected(_refresh):
		_quest_controller.quest_log_changed.connect(_refresh)
	if not _quest_controller.quest_selected.is_connected(_on_quest_selected):
		_quest_controller.quest_selected.connect(_on_quest_selected)


func _style_shell() -> void:
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.04, 0.06, 0.09, 0.82)
	_root.add_theme_stylebox_override("panel", backdrop)

	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.11, 0.13, 0.18, 0.98)
	shell.border_color = Color(0.23, 0.28, 0.36, 1.0)
	shell.set_border_width_all(1)
	shell.corner_radius_top_left = 16
	shell.corner_radius_top_right = 16
	shell.corner_radius_bottom_left = 16
	shell.corner_radius_bottom_right = 16
	shell.content_margin_left = 20
	shell.content_margin_top = 18
	shell.content_margin_right = 20
	shell.content_margin_bottom = 18
	$Root/MainShell.add_theme_stylebox_override("panel", shell)

	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.14, 0.18, 0.24, 0.96)
	left_style.border_color = Color(0.22, 0.28, 0.36, 0.95)
	left_style.set_border_width_all(1)
	left_style.corner_radius_top_left = 14
	left_style.corner_radius_bottom_left = 14
	left_style.corner_radius_top_right = 4
	left_style.corner_radius_bottom_right = 4
	left_style.content_margin_left = 0
	left_style.content_margin_top = 0
	left_style.content_margin_right = 0
	left_style.content_margin_bottom = 0
	$Root/MainShell/MainVBox/Body/LeftPane.add_theme_stylebox_override("panel", left_style)

	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.12, 0.15, 0.20, 0.98)
	right_style.border_color = Color(0.22, 0.28, 0.36, 0.95)
	right_style.set_border_width_all(1)
	right_style.corner_radius_top_left = 4
	right_style.corner_radius_bottom_left = 4
	right_style.corner_radius_top_right = 14
	right_style.corner_radius_bottom_right = 14
	$Root/MainShell/MainVBox/Body/RightPane.add_theme_stylebox_override("panel", right_style)

	var objective_banner := StyleBoxFlat.new()
	objective_banner.bg_color = Color(0.19, 0.25, 0.31, 0.98)
	objective_banner.border_color = Color(0.90, 0.82, 0.57, 0.92)
	objective_banner.border_width_left = 4
	objective_banner.corner_radius_top_left = 10
	objective_banner.corner_radius_top_right = 10
	objective_banner.corner_radius_bottom_left = 10
	objective_banner.corner_radius_bottom_right = 10
	$Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/ObjectiveBanner.add_theme_stylebox_override("panel", objective_banner)

	var block_style := StyleBoxFlat.new()
	block_style.bg_color = Color(0.10, 0.13, 0.18, 0.55)
	block_style.border_color = Color(0.22, 0.28, 0.36, 0.9)
	block_style.set_border_width_all(1)
	block_style.set_corner_radius_all(12)
	$Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/ObjectivePanel.add_theme_stylebox_override("panel", block_style)
	$Root/MainShell/MainVBox/Body/RightPane/RightScroll/RightMargin/RightVBox/FooterPanel.add_theme_stylebox_override("panel", block_style)

	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.23, 0.27, 0.35, 1.0)
	close_style.set_corner_radius_all(20)
	close_style.set_content_margin_all(0)
	_close_button.add_theme_stylebox_override("normal", close_style)
	_close_button.add_theme_stylebox_override("hover", close_style)
	_close_button.add_theme_stylebox_override("pressed", close_style)
	_close_button.add_theme_stylebox_override("focus", close_style)
	_close_button.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))

	_group_title.add_theme_color_override("font_color", Color(0.86, 0.79, 0.58))
	$Root/MainShell/MainVBox/Body/LeftPane/LeftMargin/LeftVBox/GroupCaption.add_theme_color_override("font_color", Color(0.53, 0.58, 0.69))
	_header_title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	_tracking_label.add_theme_color_override("font_color", Color(0.51, 0.58, 0.70))
	_meta_label.add_theme_color_override("font_color", Color(0.84, 0.77, 0.56))
	_summary_label.add_theme_color_override("font_color", Color(0.83, 0.85, 0.90))
	_reward_title_label.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	_empty_list_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.82))
	_empty_rewards_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.82))
	_controls_label.add_theme_color_override("font_color", Color(0.58, 0.63, 0.73))


func _refresh() -> void:
	_update_header()
	_update_tab_button_styles()
	_refresh_quest_list()
	_refresh_details()


func _update_header() -> void:
	_header_title.text = "Archive" if _tab == TAB_COMPLETED else "Ongoing"


func _refresh_quest_list() -> void:
	for child in _list_container.get_children():
		if child == _empty_list_label:
			continue
		child.queue_free()

	var view_models: Array[Dictionary] = []
	if _quest_controller != null:
		view_models = _quest_controller.get_visible_quests(_tab == TAB_COMPLETED)

	_empty_list_label.visible = view_models.is_empty()
	_empty_list_label.text = "No archived quests yet." if _tab == TAB_COMPLETED else "No ongoing quests are visible."

	for view_model in view_models:
		var entry := _instantiate_list_entry()
		_list_container.add_child(entry)
		entry.apply_view_model(view_model)
		entry.pressed.connect(_on_entry_pressed.bind(StringName(view_model.get("quest_id", &""))))


func _refresh_details() -> void:
	var view_model: Dictionary = {}
	if _quest_controller != null:
		view_model = _quest_controller.get_selected_quest_view_model()
		var should_reselect := view_model.is_empty()
		if not should_reselect:
			var show_completed := bool(view_model.get("is_completed", false))
			should_reselect = (_tab == TAB_COMPLETED) != show_completed
		if should_reselect:
			var visible_quests := _quest_controller.get_visible_quests(_tab == TAB_COMPLETED)
			if not visible_quests.is_empty():
				var quest_id := StringName(visible_quests[0].get("quest_id", &""))
				_quest_controller.select_quest(quest_id)
				view_model = _quest_controller.get_selected_quest_view_model()
			else:
				view_model = {}

	if view_model.is_empty():
		_group_title.text = "Quest Group"
		_title_label.text = "[No Quest Selected]"
		_meta_label.text = "Quest Record"
		_objective_focus_label.text = "Select a quest from the list to inspect its current objective."
		_summary_label.text = "This panel mirrors a full-screen journal layout with stronger hierarchy and a clearer focus card."
		_status_pill.text = "Idle"
		_rebuild_objectives([])
		_rebuild_rewards([])
		return

	var category_label := str(view_model.get("category_label", "Quest"))
	_group_title.text = category_label
	_title_label.text = "[%s]" % str(view_model.get("title", "Quest"))
	_meta_label.text = "%s  |  Quest Record" % category_label
	_objective_focus_label.text = str(view_model.get("current_objective_text", "No current objective."))
	_summary_label.text = str(view_model.get("summary", ""))
	_status_pill.text = str(view_model.get("status_label", "Ongoing"))
	_style_status_pill(bool(view_model.get("is_completed", false)))
	_rebuild_objectives(view_model.get("objectives", []))
	_rebuild_rewards(view_model.get("rewards", []))


func _rebuild_objectives(objectives: Array) -> void:
	for child in _objective_list.get_children():
		child.queue_free()

	if objectives.is_empty():
		var empty_label := Label.new()
		empty_label.text = "This quest does not have any objectives yet."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.69, 0.75, 0.84))
		_objective_list.add_child(empty_label)
		return

	for objective_data in objectives:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var marker := ColorRect.new()
		marker.custom_minimum_size = Vector2(3, 22)
		marker.color = Color(0.90, 0.82, 0.57, 1.0) if bool(objective_data.get("is_current", false)) else Color(0.44, 0.53, 0.66, 0.85)
		row.add_child(marker)

		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.add_theme_constant_override("separation", 3)

		var objective_label := Label.new()
		objective_label.text = str(objective_data.get("description", ""))
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_label.add_theme_font_size_override("font_size", 16)
		objective_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99) if not bool(objective_data.get("is_completed", false)) else Color(0.74, 0.86, 0.78))
		text_column.add_child(objective_label)

		var progress_label := Label.new()
		progress_label.text = str(objective_data.get("progress_text", ""))
		progress_label.add_theme_font_size_override("font_size", 13)
		progress_label.add_theme_color_override("font_color", Color(0.64, 0.70, 0.80))
		text_column.add_child(progress_label)

		row.add_child(text_column)
		_objective_list.add_child(row)


func _rebuild_rewards(rewards: Array) -> void:
	for child in _reward_list.get_children():
		child.queue_free()

	var has_rewards := not rewards.is_empty()
	_reward_title_label.visible = has_rewards
	_empty_rewards_label.visible = not has_rewards

	for reward in rewards:
		var reward_entry := _instantiate_reward_entry()
		_reward_list.add_child(reward_entry)
		reward_entry.apply_view_model(reward)


func _instantiate_list_entry() -> QuestListEntry:
	if list_entry_scene != null:
		return list_entry_scene.instantiate() as QuestListEntry
	return QuestListEntry.new()


func _instantiate_reward_entry() -> QuestRewardEntry:
	if reward_entry_scene != null:
		return reward_entry_scene.instantiate() as QuestRewardEntry
	return QuestRewardEntry.new()


func _on_entry_pressed(quest_id: StringName) -> void:
	if _quest_controller == null:
		return
	_quest_controller.select_quest(quest_id)


func _on_quest_selected(_quest_id: StringName) -> void:
	_refresh()


func _on_active_tab_pressed() -> void:
	_tab = TAB_ACTIVE
	_refresh()


func _on_completed_tab_pressed() -> void:
	_tab = TAB_COMPLETED
	_refresh()


func _hide_panel() -> void:
	_set_panel_visible(false)


func _update_tab_button_styles() -> void:
	_style_tab_button(_active_button, _tab == TAB_ACTIVE)
	_style_tab_button(_completed_button, _tab == TAB_COMPLETED)


func _style_tab_button(button: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.00, 0.00, 0.00, 0.0)
	style.border_color = Color(0.00, 0.00, 0.00, 0.0)
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color(0.90, 0.82, 0.57) if is_active else Color(0.53, 0.58, 0.69))


func _style_status_pill(is_completed: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.39, 0.31, 0.96) if is_completed else Color(0.62, 0.52, 0.20, 0.96)
	style.set_corner_radius_all(18)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_status_pill_panel.add_theme_stylebox_override("panel", style)
	_status_pill.add_theme_color_override("font_color", Color(0.98, 0.98, 0.99))
