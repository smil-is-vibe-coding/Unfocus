class_name JetSpec
extends Resource
## Everything that makes one jet class different: handling, durability, perk
## multipliers and the parameters its procedural model is built from.

@export var id := "viper"
@export var display_name := "Viper"
@export_multiline var tagline := ""
@export var ability_name := ""
@export_multiline var ability_desc := ""
@export var pros: PackedStringArray = []
@export var cons: PackedStringArray = []
@export var color := Color(0.0, 0.9, 1.0)
@export var accent := Color(1.0, 0.2, 0.8)

@export_group("Performance")
@export var top_speed := 60.0             ## m/s
@export var accel := 16.0                 ## m/s^2 at standstill
@export var power_falloff := 2.0
@export var turn_rate_low := 120.0        ## deg/s at low speed
@export var turn_rate_high := 50.0        ## deg/s at top speed
@export var grip := 5.0                   ## How fast sideways sliding is cancelled (1/s).
@export var max_lateral_accel := 26.0     ## Cornering limit (m/s^2).
@export var mass := 900.0
@export var max_health := 100.0
@export var hover_height := 1.3

@export_group("Perks")
@export var damage_taken_mult := 1.0
@export var gun_damage_mult := 1.0
@export var boost_mult := 1.0             ## Boost item / drift boost duration.
@export var invis_mult := 1.0
@export var drift_boost_mult := 1.0
@export var knockback_mult := 1.0         ## How far explosions throw it.

@export_group("Shape")
@export var length := 4.6
@export var body_width := 0.7             ## Half-width of the fuselage.
@export var body_height := 0.45           ## Half-height of the fuselage.
@export_range(0.1, 0.6) var nose_ratio := 0.32
@export var wing_span := 4.4
@export var wing_root_chord := 2.0
@export var wing_tip_chord := 0.7
@export var wing_sweep := 1.4             ## How far back the tip sits vs the root (m).
@export var wing_z := 0.5                 ## Wing centre along the body (+ = rear).
@export var wing_dihedral := 0.15         ## Tip height (negative = anhedral).
@export var canards := false
@export_range(0, 2) var fin_count := 1
@export var fin_height := 0.7
@export_range(1, 3) var engine_count := 2
@export var engine_radius := 0.22


## 0..1 ratings for the selection screen.
func rating_speed() -> float:
	return clampf(inverse_lerp(50.0, 74.0, top_speed), 0.05, 1.0)


func rating_accel() -> float:
	return clampf(inverse_lerp(9.0, 21.0, accel), 0.05, 1.0)


func rating_handling() -> float:
	var turn := inverse_lerp(30.0, 75.0, turn_rate_high)
	var lat := inverse_lerp(18.0, 36.0, max_lateral_accel)
	return clampf((turn + lat) * 0.5, 0.05, 1.0)


func rating_armor() -> float:
	return clampf(inverse_lerp(50.0, 170.0, max_health / damage_taken_mult), 0.05, 1.0)
