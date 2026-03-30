extends Resource
class_name AudioCue

@export var clips: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var volume_db := 0.0
@export var pitch_min := 1.0
@export var pitch_max := 1.0
@export var cooldown_sec := 0.0
@export var positional := false
@export var max_distance := 1200.0


func has_audio() -> bool:
	return not clips.is_empty()
