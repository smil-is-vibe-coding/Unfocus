@tool
class_name NeonGlow
extends RefCounted
## Cached materials for shaders/neon_glow.gdshader. One material per distinct
## look (colour, wire, hue cycling, pulse phase, rim), shared between objects.

const SHADER := preload("res://shaders/neon_glow.gdshader")
static var _cache := {}


static func mat(tint: Color, wire := 0.0, hue_cycle := 0.0, phase := 0.0, rim_power := 2.2, rim_strength := 3.0) -> ShaderMaterial:
	phase = snappedf(phase, 0.25)   # Bucket phases so materials stay shared.
	var key := "%s|%s|%s|%s|%s|%s" % [tint.to_html(), wire, hue_cycle, phase, rim_power, rim_strength]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("wire", wire)
		m.set_shader_parameter("hue_cycle", hue_cycle)
		m.set_shader_parameter("pulse_phase", phase)
		m.set_shader_parameter("rim_power", rim_power)
		m.set_shader_parameter("rim_strength", rim_strength)
		_cache[key] = m
	return _cache[key]
