extends CanvasLayer
class_name ChronosHud

const CHRONOS_ABILITY_ID := &"chronos"

@export var player_path: NodePath
@export var title_label_path: NodePath = NodePath("Panel/VBox/Title")
@export var player_label_path: NodePath = NodePath("Panel/VBox/Player")
@export var chronos_status_label_path: NodePath = NodePath("Panel/VBox/ChronosStatus")
@export var enemy_count_label_path: NodePath = NodePath("Panel/VBox/EnemyCount")
@export var controls_label_path: NodePath = NodePath("Panel/VBox/Controls")
@export var stamina_bar_path: NodePath = NodePath("Panel/VBox/StaminaBar")
@export var cooldown_bar_path: NodePath = NodePath("Panel/VBox/CooldownBar")

var _player: PlatformerCharacter2D
var _chronos_ability: ChronosAbility
var _title_label: Label
var _player_label: Label
var _chronos_status_label: Label
var _enemy_count_label: Label
var _controls_label: Label
var _stamina_bar: ProgressBar
var _cooldown_bar: ProgressBar

func _ready() -> void:
	_player = _resolve_player()
	_chronos_ability = _resolve_chronos_ability()
	_title_label = get_node_or_null(title_label_path) as Label
	_player_label = get_node_or_null(player_label_path) as Label
	_chronos_status_label = get_node_or_null(chronos_status_label_path) as Label
	_enemy_count_label = get_node_or_null(enemy_count_label_path) as Label
	_controls_label = get_node_or_null(controls_label_path) as Label
	_stamina_bar = get_node_or_null(stamina_bar_path) as ProgressBar
	_cooldown_bar = get_node_or_null(cooldown_bar_path) as ProgressBar
	_update_ui()

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _resolve_player()
		_chronos_ability = _resolve_chronos_ability()
	_update_ui()

func _resolve_player() -> PlatformerCharacter2D:
	if player_path != NodePath():
		var explicit_player := get_node_or_null(player_path)
		if explicit_player is PlatformerCharacter2D:
			return explicit_player as PlatformerCharacter2D

	for player in get_tree().get_nodes_in_group("Player"):
		if player is PlatformerCharacter2D:
			return player as PlatformerCharacter2D
	return null

func _resolve_chronos_ability() -> ChronosAbility:
	if not is_instance_valid(_player):
		return null
	return _player.abilities.get(String(CHRONOS_ABILITY_ID), null) as ChronosAbility

func _update_ui() -> void:
	if _title_label != null:
		_title_label.text = "Chronos Demo"

	if _controls_label != null:
		_controls_label.text = "CTRL chronos | LMB attack | Q throw / teleport | R reset encounter"

	if _enemy_count_label != null:
		var alive := 0
		var dead := 0
		for enemy in get_tree().get_nodes_in_group("Enemy"):
			if enemy.get("is_dead") == true:
				dead += 1
			else:
				alive += 1
		_enemy_count_label.text = "Enemies: %d alive / %d dead" % [alive, dead]

	if not is_instance_valid(_player):
		if _player_label != null:
			_player_label.text = "Player: missing"
		if _chronos_status_label != null:
			_chronos_status_label.text = "Chronos: unavailable"
		if _stamina_bar != null:
			_stamina_bar.value = 0.0
		if _cooldown_bar != null:
			_cooldown_bar.value = 0.0
		return

	if _chronos_ability == null:
		_chronos_ability = _resolve_chronos_ability()

	if _player_label != null:
		var status := "dead" if _player.is_dead else "ready"
		_player_label.text = "Player: %s  HP %d/%d" % [status, _player.current_health, _player.max_health]

	if _chronos_status_label != null:
		if _chronos_ability == null:
			_chronos_status_label.text = "Chronos: unavailable"
		else:
			var chronos_state := "ready"
			if _chronos_ability.is_chronos_running:
				chronos_state = "running"
			elif _chronos_ability.chronos_cooldown_left > 0.0:
				chronos_state = "cooling down"
			elif _chronos_ability.chronos_stamina <= 0.0:
				chronos_state = "recovering"
			_chronos_status_label.text = "Chronos: %s  Stamina %.0f / %.0f" % [
				chronos_state,
				_chronos_ability.chronos_stamina,
				_chronos_ability.chronos_stamina_max,
			]

	if _stamina_bar != null:
		_stamina_bar.value = _chronos_ability.chronos_stamina_percent * 100.0 if _chronos_ability != null else 0.0

	if _cooldown_bar != null:
		_cooldown_bar.value = _chronos_ability.chronos_cooldown_percent * 100.0 if _chronos_ability != null else 0.0
