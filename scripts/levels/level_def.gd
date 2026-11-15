class_name LevelDef
extends Resource
## One race level: track layout + its whole visual "vibe".

@export var id := "autodromo"
@export var display_name := "CIRCUIT"
@export var subtitle := ""
@export_range(1, 5) var difficulty := 1
@export var ui_color := Color(1.0, 0.2, 0.85)

@export_group("Track")
@export var points := PackedVector3Array()
@export var width := 24.0

@export_group("Road palette")
## Neon colour along the road: a band of the rainbow starting at `hue_offset`,
## `hue_range` wide (1.0 = full rainbow). Lower range = tighter colour scheme.
@export var hue_offset := 0.0
@export_range(0.0, 1.0) var hue_range := 1.0
@export var hue_scale := 900.0
@export var gate_colors: Array[Color] = [Color(0.0, 0.85, 1.0), Color(0.75, 0.3, 1.0), Color(1.0, 0.2, 0.75)]

@export_group("Sky")
@export var aurora_low := Color(0.05, 1.0, 0.55)
@export var aurora_mid := Color(0.1, 0.6, 1.0)
@export var aurora_high := Color(0.85, 0.2, 1.0)
@export var under_low := Color(1.0, 0.15, 0.6)
@export var under_high := Color(0.3, 0.1, 1.0)
@export var nebula_a := Color(0.22, 0.03, 0.35)
@export var nebula_b := Color(0.0, 0.12, 0.3)
@export var aurora_strength := 0.75
@export var nebula_strength := 0.25

@export_group("Lighting")
@export var ambient := Color(0.18, 0.12, 0.35)
@export var fog := Color(0.08, 0.03, 0.15)
@export var fog_density := 0.0012
@export var key_light := Color(0.55, 0.45, 1.0)

@export_group("Scenery")
@export var decor_palette: Array[Color] = [
	Color(0.0, 1.0, 1.0), Color(1.0, 0.1, 0.85), Color(0.55, 0.2, 1.0),
	Color(0.1, 1.0, 0.5), Color(1.0, 0.55, 0.1), Color(0.2, 0.5, 1.0),
]
@export var planet_a := Color(0.6, 0.2, 1.0)
@export var planet_b := Color(0.0, 0.9, 1.0)

@export_group("Post")
## Photographic negative of the whole world (HUD stays normal for readability).
@export var invert := false
@export_range(0.0, 1.0) var desaturate := 0.0
