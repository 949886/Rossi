extends Resource
class_name ChronosAbilityData

@export_group("Required Variables")
@export var player: PlatformerCharacter2D
@export var animated_sprite: AnimatedSprite2D

@export_group("Chronos")
@export var chronos_stamina_max := 100.0
@export var chronos_stamina_use_per_second := 28.0
@export var chronos_stamina_recover_per_second := 38.0
@export var chronos_stamina_recover_delay := 0.2
@export var chronos_cooldown := 0.45
@export var chronos_afterimage_interval := 0.045
@export var chronos_afterimage_fade_duration := 0.22
@export var chronos_afterimage_color := Color(0.58, 0.92, 1.0, 0.3)
@export var chronos_afterimage_min_speed := 65.0
@export var chronos_afterimage_trail_distance := 18.0
@export_range(0, 8, 1) var chronos_start_burst_count := 3
@export_range(0, 8, 1) var chronos_stop_burst_count := 2