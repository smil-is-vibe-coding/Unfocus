class_name PowerUp
extends RefCounted
## Power-up type ids and their display data.

## FORCEFIELD is applied instantly on pickup (refills edge-shield charges) and
## never occupies the item slot.
enum Type { NONE = -1, BOOST, MACHINE_GUN, INVISIBILITY, HOOKSHOT, MISSILE, REPAIR, FORCEFIELD }

const COUNT := 7

const NAMES := {
	Type.BOOST: "BOOST",
	Type.MACHINE_GUN: "MACHINE GUN",
	Type.INVISIBILITY: "INVISIBILITY",
	Type.HOOKSHOT: "HOOKSHOT",
	Type.MISSILE: "HOMING MISSILE",
	Type.REPAIR: "REPAIR",
	Type.FORCEFIELD: "FORCEFIELD",
}

const COLORS := {
	Type.BOOST: Color(0.2, 0.75, 1.0),
	Type.MACHINE_GUN: Color(1.0, 0.85, 0.15),
	Type.INVISIBILITY: Color(0.75, 0.4, 1.0),
	Type.HOOKSHOT: Color(0.2, 1.0, 0.6),
	Type.MISSILE: Color(1.0, 0.3, 0.15),
	Type.REPAIR: Color(0.4, 1.0, 0.3),
	Type.FORCEFIELD: Color(0.55, 0.95, 1.0),
}

## Short glyph shown on the hovering pickup.
const ICONS := {
	Type.BOOST: ">>",
	Type.MACHINE_GUN: "MG",
	Type.INVISIBILITY: "?",
	Type.HOOKSHOT: "J",
	Type.MISSILE: "M",
	Type.REPAIR: "+",
	Type.FORCEFIELD: "FF",
}


## Neon line-art symbol (white, tint with modulate / albedo colour).
const ICON_FILES := {
	Type.BOOST: "boost",
	Type.MACHINE_GUN: "machine_gun",
	Type.INVISIBILITY: "invisibility",
	Type.HOOKSHOT: "hookshot",
	Type.MISSILE: "missile",
	Type.REPAIR: "repair",
	Type.FORCEFIELD: "forcefield",
}

static var _icon_cache := {}


static func icon_texture(t: int) -> Texture2D:
	if not ICON_FILES.has(t):
		return null
	if not _icon_cache.has(t):
		_icon_cache[t] = load("res://assets/icons/%s.svg" % ICON_FILES[t])
	return _icon_cache[t]


static func name_of(t: int) -> String:
	return NAMES.get(t, "")


static func color_of(t: int) -> Color:
	return COLORS.get(t, Color.WHITE)


static func icon_of(t: int) -> String:
	return ICONS.get(t, "")
