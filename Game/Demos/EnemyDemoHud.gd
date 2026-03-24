extends CanvasLayer
class_name EnemyDemoHud

@export var player_path: NodePath
@export var title_label_path: NodePath = NodePath("Panel/VBox/Title")
@export var enemy_count_label_path: NodePath = NodePath("Panel/VBox/EnemyCount")
@export var player_label_path: NodePath = NodePath("Panel/VBox/Player")
@export var controls_label_path: NodePath = NodePath("Panel/VBox/Controls")

var _player: Node
var _title_label: Label
var _enemy_count_label: Label
var _player_label: Label
var _controls_label: Label

func _ready() -> void:
	_player = _resolve_player()
	_title_label = get_node_or_null(title_label_path)
	_enemy_count_label = get_node_or_null(enemy_count_label_path)
	_player_label = get_node_or_null(player_label_path)
	_controls_label = get_node_or_null(controls_label_path)
	_update_labels()

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _resolve_player()
	_update_labels()

func _resolve_player() -> Node:
	if player_path != NodePath():
		var explicit_player := get_node_or_null(player_path)
		if explicit_player != null:
			return explicit_player

	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		return players[0]
	return null

func _update_labels() -> void:
	if _title_label != null:
		_title_label.text = "Enemy Demo"

	if _controls_label != null:
		_controls_label.text = "LMB attack | Q throw/teleport | F switch laser | R reset encounter"

	if _enemy_count_label != null:
		var alive := 0
		var total := 0
		var dead := 0
		for enemy in get_tree().get_nodes_in_group("Enemy"):
			total += 1
			var dead_state = enemy.get("is_dead")
			if dead_state == true:
				dead += 1
			else:
				alive += 1
		var spawner_total := get_tree().get_nodes_in_group("EnemySpawner").size()
		_enemy_count_label.text = "Enemies: %d alive / %d dead / %d spawners" % [alive, dead, spawner_total]

	if _player_label != null:
		if not is_instance_valid(_player):
			_player_label.text = "Player: missing"
			return

		var current_health = _player.get("current_health")
		var max_health = _player.get("max_health")
		var dead_state = _player.get("is_dead")
		var status := "dead" if dead_state == true else "ready"
		_player_label.text = "Player: %s  HP %s/%s" % [status, str(current_health), str(max_health)]
