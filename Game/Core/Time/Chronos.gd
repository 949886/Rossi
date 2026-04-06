extends Node

const WORLD_GROUP := &"world"
const PLAYER_GROUP := &"player"
const ENEMY_GROUP := &"enemy"
const PROJECTILE_GROUP := &"projectile"

@export_group("Chronos Time Scale")
@export_range(0.01, 1.0, 0.01) var world_time_scale := 0.2
@export_range(0.01, 1.0, 0.01) var player_time_scale := 0.5
@export_range(0.01, 1.0, 0.01) var enemy_time_scale := 0.2
@export_range(0.01, 1.0, 0.01) var projectile_time_scale := 0.2

var _chronos_enabled := false
var _real_delta := 0.0
var _last_ticks_usec := 0
var _hitstop_left := 0.0
var _hitstop_time_scale := 1.0
var _elapsed_time_by_group: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks_usec = Time.get_ticks_usec()
	_reset_elapsed_time()
	_apply_engine_time_scale()

func _process(_delta: float) -> void:
	var now_ticks := Time.get_ticks_usec()
	if _last_ticks_usec <= 0:
		_last_ticks_usec = now_ticks
	_real_delta = maxf(0.0, float(now_ticks - _last_ticks_usec) / 1000000.0)
	_last_ticks_usec = now_ticks

	if _hitstop_left > 0.0:
		_hitstop_left = maxf(0.0, _hitstop_left - _real_delta)
		if _hitstop_left <= 0.0:
			_hitstop_time_scale = 1.0

	_advance_elapsed_time()
	_apply_engine_time_scale()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func set_chronos_enabled(enabled: bool) -> void:
	_chronos_enabled = enabled
	_apply_engine_time_scale()

func is_chronos_enabled() -> bool:
	return _chronos_enabled

func play_hitstop(duration: float, time_scale: float = 0.05) -> void:
	if duration <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, duration)
	_hitstop_time_scale = minf(_hitstop_time_scale, clampf(time_scale, 0.001, 1.0))
	_apply_engine_time_scale()

func get_delta_for_group(delta: float, time_group: StringName) -> float:
	return delta * get_relative_time_scale_for_group(time_group)

func get_elapsed_time_for_group(time_group: StringName) -> float:
	var group_name := _normalize_time_group(time_group)
	return float(_elapsed_time_by_group.get(group_name, 0.0))

func get_time_scale_for_group(time_group: StringName) -> float:
	var group_scale := _get_chronos_time_scale_for_group(time_group)
	return minf(group_scale, _get_global_time_scale())

func get_relative_time_scale_for_group(time_group: StringName) -> float:
	var engine_time_scale := maxf(Engine.time_scale, 0.00001)
	return get_time_scale_for_group(time_group) / engine_time_scale

func get_real_delta() -> float:
	return _real_delta

func _advance_elapsed_time() -> void:
	for group_name in _elapsed_time_by_group.keys():
		_elapsed_time_by_group[group_name] = float(_elapsed_time_by_group[group_name]) + _real_delta * get_time_scale_for_group(group_name)

func _reset_elapsed_time() -> void:
	_elapsed_time_by_group = {
		WORLD_GROUP: 0.0,
		PLAYER_GROUP: 0.0,
		ENEMY_GROUP: 0.0,
		PROJECTILE_GROUP: 0.0,
	}

func _apply_engine_time_scale() -> void:
	Engine.time_scale = clampf(_get_global_time_scale(), 0.001, 1.0)

func _get_global_time_scale() -> float:
	var global_time_scale := _get_chronos_time_scale_for_group(WORLD_GROUP)
	if _hitstop_left > 0.0:
		global_time_scale = minf(global_time_scale, _hitstop_time_scale)
	return clampf(global_time_scale, 0.001, 1.0)

func _get_chronos_time_scale_for_group(time_group: StringName) -> float:
	if not _chronos_enabled:
		return 1.0

	match _normalize_time_group(time_group):
		PLAYER_GROUP:
			return player_time_scale
		ENEMY_GROUP:
			return enemy_time_scale
		PROJECTILE_GROUP:
			return projectile_time_scale
		_:
			return world_time_scale

func _normalize_time_group(time_group: StringName) -> StringName:
	if time_group.is_empty():
		return WORLD_GROUP
	if _elapsed_time_by_group.has(time_group):
		return time_group
	return WORLD_GROUP
