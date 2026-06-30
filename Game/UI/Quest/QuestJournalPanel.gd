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
@onready var _active_button: Button = $Root/MainShell/Header/TabRow/ActiveButton
@onready var _completed_button: Button = $Root/MainShell/Header/TabRow/CompletedButton
@onready var _list_container: VBoxContainer = $Root/MainShell/Body/LeftPane/LeftMargin/QuestListScroll/QuestList
@onready var _empty_list_label: Label = $Root/MainShell/Body/LeftPane/LeftMargin/QuestListScroll/QuestList/EmptyLabel
@onready var _title_label: Label = $Root/MainShell/Body/RightPane/TitleBlock/Title
@onready var _subtitle_label: Label = $Root/MainShell/Body/RightPane/TitleBlock/Subtitle
@onready var _summary_label: Label = $Root/MainShell/Body/RightPane/TitleBlock/Summary
@onready var _objective_list: VBoxContainer = $Root/MainShell/Body/RightPane/ObjectivePanel/ObjectiveMargin/ObjectiveVBox/ObjectiveList
@onready var _reward_list: HBoxContainer = $Root/MainShell/Body/RightPane/RewardPanel/RewardMargin/RewardVBox/RewardList
@onready var _empty_rewards_label: Label = $Root/MainShell/Body/RightPane/RewardPanel/RewardMargin/RewardVBox/EmptyRewards

var _quest_controller: QuestLogController
var _tab := TAB_ACTIVE


func _ready() -> void:
	layer = 18
	visible = true
	_root.visible = open_by_default
	_style_shell()
	_resolve_controller()

	_active_button.pressed.connect(_on_active_tab_pressed)
	_completed_button.pressed.connect(_on_completed_tab_pressed)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		_root.visible = not _root.visible
		if _root.visible:
			_refresh()
		get_viewport().set_input_as_handled()


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
	backdrop.bg_color = Color(0.04, 0.06, 0.08, 0.62)
	_root.add_theme_stylebox_override("panel", backdrop)

	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.10, 0.13, 0.18, 0.92)
	shell.border_color = Color(0.76, 0.69, 0.48, 0.9)
	shell.set_border_width_all(2)
	shell.corner_radius_top_left = 16
	shell.corner_radius_top_right = 16
	shell.corner_radius_bottom_left = 16
	shell.corner_radius_bottom_right = 16
	shell.content_margin_left = 14
	shell.content_margin_top = 14
	shell.content_margin_right = 14
	shell.content_margin_bottom = 14
	$Root/MainShell.add_theme_stylebox_override("panel", shell)

	var section_style := StyleBoxFlat.new()
	section_style.bg_color = Color(0.12, 0.16, 0.22, 0.84)
	section_style.border_color = Color(0.42, 0.52, 0.64, 0.7)
	section_style.set_border_width_all(1)
	section_style.set_corner_radius_all(12)
	section_style.set_content_margin_all(8)

	$Root/MainShell/Body/LeftPane.add_theme_stylebox_override("panel", section_style)
	$Root/MainShell/Body/RightPane/ObjectivePanel.add_theme_stylebox_override("panel", section_style)
	$Root/MainShell/Body/RightPane/RewardPanel.add_theme_stylebox_override("panel", section_style)


func _refresh() -> void:
	_update_tab_button_styles()
	_refresh_quest_list()
	_refresh_details()


func _refresh_quest_list() -> void:
	for child in _list_container.get_children():
		if child == _empty_list_label:
			continue
		child.queue_free()

	var view_models: Array[Dictionary] = []
	if _quest_controller != null:
		view_models = _quest_controller.get_visible_quests(_tab == TAB_COMPLETED)

	_empty_list_label.visible = view_models.is_empty()
	if _empty_list_label.visible:
		_empty_list_label.text = "No quests are visible in this tab."

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
		_title_label.text = "No Quest Selected"
		_subtitle_label.text = "Quest subtitle or location appears here."
		_summary_label.text = "Select a quest from the list to inspect its details."
		_rebuild_objectives([])
		_rebuild_rewards([])
		return

	_title_label.text = str(view_model.get("title", ""))
	_subtitle_label.text = str(view_model.get("subtitle", ""))
	_summary_label.text = str(view_model.get("summary", ""))
	_rebuild_objectives(view_model.get("objectives", []))
	_rebuild_rewards(view_model.get("rewards", []))


func _rebuild_objectives(objectives: Array) -> void:
	for child in _objective_list.get_children():
		child.queue_free()

	if objectives.is_empty():
		var empty_label := Label.new()
		empty_label.text = "This quest does not have any objectives yet."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.92))
		_objective_list.add_child(empty_label)
		return

	for objective_data in objectives:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var bullet := Label.new()
		var is_completed := bool(objective_data.get("is_completed", false))
		var is_current := bool(objective_data.get("is_current", false))
		bullet.text = ">" if is_current else ("*" if is_completed else "-")
		bullet.add_theme_font_size_override("font_size", 18)
		bullet.add_theme_color_override("font_color", Color(0.95, 0.84, 0.55) if is_current else Color(0.77, 0.82, 0.9))
		row.add_child(bullet)

		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.add_theme_constant_override("separation", 2)

		var objective_label := Label.new()
		objective_label.text = str(objective_data.get("description", ""))
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.99) if not is_completed else Color(0.72, 0.86, 0.74))
		text_column.add_child(objective_label)

		var progress_label := Label.new()
		progress_label.text = str(objective_data.get("progress_text", ""))
		progress_label.add_theme_font_size_override("font_size", 14)
		progress_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.62))
		text_column.add_child(progress_label)

		row.add_child(text_column)
		_objective_list.add_child(row)


func _rebuild_rewards(rewards: Array) -> void:
	for child in _reward_list.get_children():
		child.queue_free()

	_empty_rewards_label.visible = rewards.is_empty()
	if rewards.is_empty():
		return

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


func _update_tab_button_styles() -> void:
	_style_tab_button(_active_button, _tab == TAB_ACTIVE)
	_style_tab_button(_completed_button, _tab == TAB_COMPLETED)


func _style_tab_button(button: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.66, 0.49, 0.92) if is_active else Color(0.16, 0.20, 0.27, 0.92)
	style.border_color = Color(0.94, 0.84, 0.56, 0.95) if is_active else Color(0.42, 0.52, 0.64, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08) if is_active else Color(0.94, 0.96, 1.0))
