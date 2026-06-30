extends Node
class_name QuestLogController

signal quest_log_changed
signal quest_selected(quest_id: StringName)
signal quest_updated(quest_id: StringName)
signal quest_completed(quest_id: StringName)

@export var quest_set: QuestSetData
@export var auto_load_on_ready := true

var _quest_by_id: Dictionary = {}
var _quest_order: Array[StringName] = []
var _quest_states: Dictionary = {}
var _selected_quest_id: StringName = &""


func _ready() -> void:
	if auto_load_on_ready and quest_set != null:
		load_quest_set(quest_set)


func load_quest_set(value: QuestSetData) -> void:
	quest_set = value
	_quest_by_id.clear()
	_quest_order.clear()
	_quest_states.clear()
	_selected_quest_id = &""

	if quest_set == null:
		quest_log_changed.emit()
		return

	var quests := quest_set.quests.duplicate()
	quests.sort_custom(_sort_quests)

	for quest_data in quests:
		if quest_data == null:
			continue
		var quest_id := _normalize_quest_id(quest_data)
		if String(quest_id).is_empty():
			continue
		_quest_by_id[quest_id] = quest_data
		_quest_order.append(quest_id)
		_quest_states[quest_id] = _create_initial_state(quest_data)

	var visible_active := get_visible_quests(false)
	if not visible_active.is_empty():
		_selected_quest_id = StringName(visible_active[0].get("quest_id", &""))
	elif not _quest_order.is_empty():
		_selected_quest_id = _quest_order[0]

	quest_log_changed.emit()
	if not String(_selected_quest_id).is_empty():
		quest_selected.emit(_selected_quest_id)


func select_quest(quest_id: StringName) -> void:
	if not _quest_by_id.has(quest_id):
		return
	if _selected_quest_id == quest_id:
		return
	_selected_quest_id = quest_id
	quest_selected.emit(quest_id)
	quest_log_changed.emit()


func start_quest(quest_id: StringName) -> void:
	var state: Dictionary = _quest_states.get(quest_id, {})
	if state.is_empty():
		return
	if state.get("is_completed", false):
		return
	if state.get("is_active", false):
		return

	state["is_unlocked"] = true
	state["is_active"] = true
	_quest_states[quest_id] = state
	if String(_selected_quest_id).is_empty():
		_selected_quest_id = quest_id
		quest_selected.emit(quest_id)
	quest_updated.emit(quest_id)
	quest_log_changed.emit()


func record_event(event_key: StringName, payload := {}) -> void:
	if String(event_key).is_empty():
		return

	var changed_quests: Array[StringName] = []
	var completed_quests: Array[StringName] = []

	for quest_id in _quest_order:
		var quest_data: QuestData = _quest_by_id.get(quest_id)
		if quest_data == null:
			continue

		var state: Dictionary = _quest_states.get(quest_id, {})
		if state.is_empty():
			continue
		if not state.get("is_active", false):
			continue
		if state.get("is_completed", false):
			continue

		var current_index := int(state.get("current_objective_index", 0))
		if current_index < 0 or current_index >= quest_data.objectives.size():
			continue

		var objective: QuestObjectiveData = quest_data.objectives[current_index]
		if objective == null or objective.event_key != event_key:
			continue

		var progress: Array = state.get("objective_progress", [])
		if progress.size() != quest_data.objectives.size():
			progress = _build_progress_array(quest_data)

		var next_count: int = int(progress[current_index]) + 1
		if objective.auto_complete_on_match:
			next_count = objective.get_effective_required_count()
		progress[current_index] = min(next_count, objective.get_effective_required_count())
		state["objective_progress"] = progress

		if progress[current_index] >= objective.get_effective_required_count():
			state["current_objective_index"] = current_index + 1
			if current_index + 1 >= quest_data.objectives.size():
				state["is_completed"] = true
				state["is_active"] = false
				completed_quests.append(quest_id)
				if _selected_quest_id == quest_id:
					_selected_quest_id = _find_fallback_selection()
			else:
				state["is_active"] = true
		_quest_states[quest_id] = state
		changed_quests.append(quest_id)

	for quest_id in changed_quests:
		quest_updated.emit(quest_id)
	for quest_id in completed_quests:
		quest_completed.emit(quest_id)

	if not changed_quests.is_empty():
		if String(_selected_quest_id).is_empty():
			_selected_quest_id = _find_fallback_selection()
		quest_log_changed.emit()


func get_selected_quest_view_model() -> Dictionary:
	if String(_selected_quest_id).is_empty():
		return {}
	return _build_quest_view_model(_selected_quest_id)


func get_visible_quests(include_completed: bool = false) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for quest_id in _quest_order:
		var state: Dictionary = _quest_states.get(quest_id, {})
		if state.is_empty():
			continue
		var is_completed := bool(state.get("is_completed", false))
		if include_completed != is_completed:
			continue
		if not is_completed and not state.get("is_active", false):
			continue
		visible.append(_build_quest_view_model(quest_id))
	return visible


func get_quest_data(quest_id: StringName) -> QuestData:
	return _quest_by_id.get(quest_id) as QuestData


func _sort_quests(a: QuestData, b: QuestData) -> bool:
	if a == null:
		return false
	if b == null:
		return true
	if a.sort_order == b.sort_order:
		return String(_normalize_quest_id(a)) < String(_normalize_quest_id(b))
	return a.sort_order < b.sort_order


func _normalize_quest_id(quest_data: QuestData) -> StringName:
	if quest_data == null:
		return &""
	if not String(quest_data.quest_id).is_empty():
		return quest_data.quest_id
	return StringName(quest_data.resource_path.get_file().get_basename())


func _create_initial_state(quest_data: QuestData) -> Dictionary:
	var progress := _build_progress_array(quest_data)
	var is_completed := quest_data.starts_completed
	var is_active := quest_data.starts_active and not is_completed
	var current_index := 0

	if is_completed:
		for i in range(progress.size()):
			var objective := quest_data.objectives[i]
			if objective != null:
				progress[i] = objective.get_effective_required_count()
		current_index = quest_data.objectives.size()

	return {
		"is_unlocked": is_active or is_completed,
		"is_active": is_active,
		"is_completed": is_completed,
		"current_objective_index": current_index,
		"objective_progress": progress,
	}


func _build_progress_array(quest_data: QuestData) -> Array[int]:
	var progress: Array[int] = []
	for _objective in quest_data.objectives:
		progress.append(0)
	return progress


func _build_quest_view_model(quest_id: StringName) -> Dictionary:
	var quest_data: QuestData = _quest_by_id.get(quest_id)
	var state: Dictionary = _quest_states.get(quest_id, {})
	if quest_data == null or state.is_empty():
		return {}

	var objectives: Array[Dictionary] = []
	var progress: Array = state.get("objective_progress", [])
	var current_index := int(state.get("current_objective_index", 0))
	var completed_count := 0

	for i in range(quest_data.objectives.size()):
		var objective: QuestObjectiveData = quest_data.objectives[i]
		if objective == null:
			continue

		var required := objective.get_effective_required_count()
		var current := 0
		if i < progress.size():
			current = int(progress[i])
		var is_complete := current >= required or i < current_index
		if is_complete:
			completed_count += 1

		objectives.append({
			"objective_id": objective.objective_id,
			"description": objective.description,
			"event_key": objective.event_key,
			"required_count": required,
			"current_count": min(current, required),
			"target_display_name": objective.target_display_name,
			"is_completed": is_complete,
			"is_current": not bool(state.get("is_completed", false)) and i == current_index,
			"progress_text": _format_objective_progress(objective, current, required),
		})

	var reward_models: Array[Dictionary] = []
	for reward in quest_data.rewards:
		if reward == null:
			continue
		reward_models.append({
			"label": reward.label,
			"amount": reward.amount,
			"icon": reward.icon,
		})

	var is_completed := bool(state.get("is_completed", false))
	return {
		"quest_id": quest_id,
		"title": quest_data.get_safe_title(),
		"subtitle": quest_data.subtitle,
		"summary": quest_data.summary,
		"category": quest_data.category,
		"sort_order": quest_data.sort_order,
		"status": "completed" if is_completed else "active",
		"status_label": "Completed" if is_completed else "Active",
		"is_completed": is_completed,
		"is_active": bool(state.get("is_active", false)),
		"is_selected": _selected_quest_id == quest_id,
		"current_objective_index": current_index,
		"completed_objective_count": completed_count,
		"objective_count": objectives.size(),
		"objectives": objectives,
		"rewards": reward_models,
	}


func _format_objective_progress(objective: QuestObjectiveData, current: int, required: int) -> String:
	if objective == null:
		return ""
	if objective.auto_complete_on_match and required <= 1:
		return "Done" if current >= required else "Pending"
	if required <= 1:
		return "1/1" if current >= required else "0/1"
	return "%d/%d" % [min(current, required), required]


func _find_fallback_selection() -> StringName:
	var active := get_visible_quests(false)
	if not active.is_empty():
		return StringName(active[0].get("quest_id", &""))
	var completed := get_visible_quests(true)
	if not completed.is_empty():
		return StringName(completed[0].get("quest_id", &""))
	return &""
