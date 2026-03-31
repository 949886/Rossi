class_name SFX extends Object

const MAX_PLAYERS: int = 8

const ROOT_BUS: StringName = &"SFX"
const PLAYER_BUS: StringName = &"SFX_Player"
const ENEMY_BUS: StringName = &"SFX_Enemy"
const IMPACT_BUS: StringName = &"SFX_Impact"

static var _players: Array[AudioStreamPlayer] = []
static var _players_2d: Array[AudioStreamPlayer2D] = []
static var _container: Node = null
static var _container_2d: Node2D = null

static func _static_init() -> void:
	_ensure_initialized()


## Play a sound effect globally (non-positional)
static func play(audio: AudioStream, bus: StringName = ROOT_BUS, volume_db := 0.0, pitch_scale := 1.0) -> void:
	if not audio:
		return

	if not _ensure_initialized():
		return

	var player := _get_idle_player()
	if player == null:
		return
	player.stream = audio
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## Play a random sound from an array of AudioStreams
static func play_randomly(
	audio_list: Array[AudioStream],
	bus: StringName = ROOT_BUS,
	volume_db := 0.0,
	pitch_min := 1.0,
	pitch_max := 1.0
) -> void:
	if audio_list.is_empty():
		return

	play(audio_list[randi() % audio_list.size()], bus, volume_db, _get_random_pitch_scale(pitch_min, pitch_max))


static func play_2d(
	audio: AudioStream,
	position: Vector2,
	bus: StringName = ROOT_BUS,
	volume_db := 0.0,
	pitch_scale := 1.0,
	max_distance := 1200.0
) -> void:
	if not audio:
		return

	if not _ensure_initialized():
		return

	var player := _get_idle_player_2d()
	if player == null:
		return
	player.stream = audio
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = maxf(1.0, max_distance)
	player.global_position = position
	player.play()


static func play_randomly_2d(
	audio_list: Array[AudioStream],
	position: Vector2,
	bus: StringName = ROOT_BUS,
	volume_db := 0.0,
	pitch_min := 1.0,
	pitch_max := 1.0,
	max_distance := 1200.0
) -> void:
	if audio_list.is_empty():
		return

	play_2d(
		audio_list[randi() % audio_list.size()],
		position,
		bus,
		volume_db,
		_get_random_pitch_scale(pitch_min, pitch_max),
		max_distance
	)


static func play_cue(cue: AudioCue, position := Vector2.ZERO) -> void:
	if cue == null or not cue.has_audio():
		return

	if cue.positional:
		play_randomly_2d(cue.clips, position, cue.bus, cue.volume_db, cue.pitch_min, cue.pitch_max, cue.max_distance)
	else:
		play_randomly(cue.clips, cue.bus, cue.volume_db, cue.pitch_min, cue.pitch_max)


static func _get_idle_player() -> AudioStreamPlayer:
	if not _ensure_initialized():
		return null

	# Return the first player that is not currently playing
	for player in _players:
		if is_instance_valid(player) and not player.playing:
			return player

	# If no idle player is available, create a new one
	var new_player := AudioStreamPlayer.new()
	new_player.name = "SFX Player %d" % _players.size()
	_container.add_child(new_player)
	_players.append(new_player)

	return new_player


static func _get_idle_player_2d() -> AudioStreamPlayer2D:
	if not _ensure_initialized():
		return null

	for player in _players_2d:
		if is_instance_valid(player) and not player.playing:
			return player

	var new_player := AudioStreamPlayer2D.new()
	new_player.name = "SFX Player2D %d" % _players_2d.size()
	_container_2d.add_child(new_player)
	_players_2d.append(new_player)
	return new_player


static func _ensure_initialized() -> bool:
	_ensure_audio_buses()
	if is_instance_valid(_container) and is_instance_valid(_container_2d):
		return true

	var root := (Engine.get_main_loop() as SceneTree).root
	if root == null:
		printerr("SFX Module: Unable to initialize - root node not found")
		return false

	if not is_instance_valid(_container):
		_players.clear()
		_container = Node.new()
		_container.name = "SFX Players"
		root.add_child(_container)
		for i in range(MAX_PLAYERS):
			var player := AudioStreamPlayer.new()
			player.name = "SFX Player %d" % i
			_container.add_child(player)
			_players.append(player)

	if not is_instance_valid(_container_2d):
		_players_2d.clear()
		_container_2d = Node2D.new()
		_container_2d.name = "SFX Players2D"
		root.add_child(_container_2d)
		for i in range(MAX_PLAYERS):
			var player_2d := AudioStreamPlayer2D.new()
			player_2d.name = "SFX Player2D %d" % i
			_container_2d.add_child(player_2d)
			_players_2d.append(player_2d)

	return true


static func _ensure_audio_buses() -> void:
	_ensure_bus(ROOT_BUS, &"Master")
	_ensure_bus(PLAYER_BUS, ROOT_BUS)
	_ensure_bus(ENEMY_BUS, ROOT_BUS)
	_ensure_bus(IMPACT_BUS, ROOT_BUS)


static func _ensure_bus(bus_name: StringName, send_to: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)

	if AudioServer.get_bus_index(send_to) != -1:
		AudioServer.set_bus_send(bus_index, send_to)


static func _get_random_pitch_scale(pitch_min: float, pitch_max: float) -> float:
	var min_pitch := minf(pitch_min, pitch_max)
	var max_pitch := maxf(pitch_min, pitch_max)
	if is_equal_approx(min_pitch, max_pitch):
		return min_pitch
	return randf_range(min_pitch, max_pitch)
