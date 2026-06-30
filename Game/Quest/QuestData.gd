@tool
extends Resource
class_name QuestData

@export var quest_id: StringName
@export var title := ""
@export var subtitle := ""
@export_multiline var summary := ""
@export var category: StringName = &"world"
@export var sort_order := 0
@export var objectives: Array[QuestObjectiveData] = []
@export var rewards: Array[QuestRewardData] = []
@export var starts_active := true
@export var starts_completed := false


func get_safe_title() -> String:
	if not title.is_empty():
		return title
	if not String(quest_id).is_empty():
		return String(quest_id).replace("_", " ").capitalize()
	return "Untitled Quest"
