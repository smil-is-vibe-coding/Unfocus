class_name CarItems
extends Node3D
## Three-slot item inventory + active item effects for a HoverJet.
## Abilities can be fired forward or backward (gun, missile, hookshot).
## Created automatically by HoverJet._ready().

@export_group("Boost")
@export var boost_duration := 3.0

@export_group("Machine Gun")
@export var gun_rounds := 40
@export var gun_fire_rate := 14.0       ## rounds per second
@export var gun_damage := 2.5
@export var gun_range := 140.0
## No auto-aim: bullets go where the car points. AI only opens fire when a
## target is inside this cone.
@export var gun_aim_cone_deg := 5.0
@export var gun_spread_deg := 0.6
@export var gun_hit_impulse := 250.0

@export_group("Invisibility")
@export var invisibility_duration := 7.0

@export_group("Hookshot")
@export var hook_range := 90.0
@export var hook_cone_deg := 30.0
@export var hook_duration := 1.6
@export var hook_pull_target := 26000.0  ## Drags the target back toward you (N).
@export var hook_pull_self := 16000.0    ## Slingshots you toward the target (N).
@export var hook_damage := 8.0

@export_group("Missile")
@export var missile_lock_range := 90.0     ## Must have a target this close at launch to lock on.
@export var missile_lock_cone_deg := 45.0

@export_group("Repair")
@export var repair_amount := 50.0

var car: HoverJet
const SLOT_COUNT := 3
## Abilities that can be aimed backward with ↓. Everything else only fires with ↑.
const DIRECTIONAL := [PowerUp.Type.MACHINE_GUN, PowerUp.Type.HOOKSHOT, PowerUp.Type.MISSILE]
var slots: Array[int] = [PowerUp.Type.NONE, PowerUp.Type.NONE, PowerUp.Type.NONE]
var selected := 0
## Item in the selected slot (read-only convenience).
var held: int:
	get:
		return slots[selected]

var gun_ammo := 0
var _gun_cooldown := 0.0
var _gun_side := 1.0
var _gun_backward := false

var hook_target: HoverJet
var _hook: VenomHook

var invis_time := 0.0


func _ready() -> void:
	car = get_parent() as HoverJet


static func is_directional(t: int) -> bool:
	return t in DIRECTIONAL


func count() -> int:
	return slots.count(PowerUp.Type.NONE) * -1 + SLOT_COUNT


## Puts the item in the first free slot. Returns false when all slots are full.
func give(type: int) -> bool:
	if car.is_destroyed:
		return false
	var free := slots.find(PowerUp.Type.NONE)
	if free < 0:
		return false
	slots[free] = type
	if slots[selected] == PowerUp.Type.NONE:
		selected = free
	car.item_changed.emit(held)
	return true


## Training helper: give even when full (replaces the selected slot).
func force_give(type: int) -> void:
	if not give(type):
		slots[selected] = type
		car.item_changed.emit(held)


## Move the selection left (-1) / right (+1).
func cycle(dir: int) -> void:
	selected = posmod(selected + dir, SLOT_COUNT)
	car.item_changed.emit(held)


func clear() -> void:
	for i in SLOT_COUNT:
		slots[i] = PowerUp.Type.NONE
	gun_ammo = 0
	_release_hook()
	if invis_time > 0.0:
		invis_time = 0.0
		car.set_invisible(false)
	car.item_changed.emit(held)


## Fire the selected ability. `backward` aims gun / missile / hookshot behind.
func use(backward := false) -> void:
	if held == PowerUp.Type.NONE or car.is_destroyed:
		return
	if backward and not is_directional(held):
		return  # Boost / invisibility / repair only go off with ↑.
	var type := held
	slots[selected] = PowerUp.Type.NONE
	# Hop to the next filled slot so the next press is ready to go.
	for k in range(1, SLOT_COUNT):
		var j := (selected + k) % SLOT_COUNT
		if slots[j] != PowerUp.Type.NONE:
			selected = j
			break
	match type:
		PowerUp.Type.BOOST:
			car.start_boost(boost_duration * car.spec.boost_mult)
			var tail := car.global_position + car.global_basis.z * car.spec.length * 0.6
			Effects.ring_burst(car.get_parent(), tail, PowerUp.color_of(type), 5.0, 3, car.global_basis.z)
			Effects.flash(car.get_parent(), tail, PowerUp.color_of(type), 2.5, 0.3)
		PowerUp.Type.MACHINE_GUN:
			gun_ammo = gun_rounds
			_gun_cooldown = 0.0
			_gun_backward = backward
		PowerUp.Type.INVISIBILITY:
			invis_time = invisibility_duration * car.spec.invis_mult
			car.set_invisible(true)
			car._sfx("invis_on", car.global_position)
			_phase_burst()
		PowerUp.Type.HOOKSHOT:
			_fire_hook(backward)
		PowerUp.Type.MISSILE:
			_fire_missile(backward)
		PowerUp.Type.REPAIR:
			car.repair(repair_amount)
			car._sfx("repair", car.global_position)
			_repair_fx()
	car.item_changed.emit(held)


func _physics_process(delta: float) -> void:
	if car == null:
		return
	if gun_ammo > 0:
		_update_gun(delta)
	if invis_time > 0.0:
		invis_time -= delta
		if invis_time <= 0.0:
			car.set_invisible(false)
			car._sfx("invis_off", car.global_position)
			_phase_burst()


func _phase_burst() -> void:
	var c := PowerUp.color_of(PowerUp.Type.INVISIBILITY)
	Effects.flash(car.get_parent(), car.global_position, c, 4.0, 0.35, 3.0)
	Effects.shockwave(car.get_parent(), car.global_position, c, 7.0, 0.5)
	Effects.shockwave(car.get_parent(), car.global_position, Color(0.2, 1.0, 1.0), 5.0, 0.6, car.global_basis.z)
	Effects.sparks(car.get_parent(), car.global_position, c, 30, 16.0, 0.6)


func _repair_fx() -> void:
	var c := PowerUp.color_of(PowerUp.Type.REPAIR)
	var world := car.get_parent()
	for i in 3:
		var tw := car.create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_callback(func() -> void:
			if is_instance_valid(car):
				Effects.shockwave(world, car.global_position + Vector3.UP * (0.3 + i * 0.8), c, 3.5, 0.5))
	Effects.sparks(world, car.global_position, c, 30, 9.0, 0.9, Vector3.UP, 40.0, 3.0)


# --- Targeting ----------------------------------------------------------------

## Nearest targetable car in front of `from_car` inside a cone, or null.
static func find_target(from_car: HoverJet, max_range: float, cone_deg: float, backward := false) -> HoverJet:
	var best: HoverJet = null
	var best_score := INF
	var origin := from_car.global_position
	var fwd := from_car.global_basis.z if backward else -from_car.global_basis.z
	var cos_cone := cos(deg_to_rad(cone_deg))
	for node in from_car.get_tree().get_nodes_in_group("cars"):
		var other := node as HoverJet
		if other == null or other == from_car or not other.is_targetable():
			continue
		var to := other.global_position - origin
		var dist := to.length()
		if dist > max_range or dist < 0.5:
			continue
		var cos_a := fwd.dot(to / dist)
		if cos_a < cos_cone:
			continue
		# Prefer close and centred targets.
		var score := dist * (2.0 - cos_a)
		if score < best_score:
			best_score = score
			best = other
	return best


# --- Machine gun ------------------------------------------------------------------

func _update_gun(delta: float) -> void:
	_gun_cooldown -= delta
	while _gun_cooldown <= 0.0 and gun_ammo > 0:
		_gun_cooldown += 1.0 / gun_fire_rate
		gun_ammo -= 1
		_fire_bullet()


func _fire_bullet() -> void:
	_gun_side = -_gun_side
	var muzzle := car.tail_point(_gun_side) if _gun_backward else car.nose_point(_gun_side)
	# Fire straight along the nose (or tail): aiming is done with the steering.
	var dir := car.global_basis.z if _gun_backward else -car.global_basis.z
	var spread := deg_to_rad(gun_spread_deg)
	dir = dir.rotated(car.global_basis.y, randf_range(-spread, spread)).rotated(car.global_basis.x, randf_range(-spread, spread) * 0.5)

	var end := muzzle + dir * gun_range
	var query := PhysicsRayQueryParameters3D.create(muzzle, end)
	query.exclude = [car.get_rid()]
	var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
	var world := car.get_parent()
	car._sfx("gun_shot", muzzle, 0.0, randf_range(0.92, 1.1))
	var bolt := PowerUp.color_of(PowerUp.Type.MACHINE_GUN)
	Effects.muzzle_flash(world, muzzle, dir, bolt)
	if hit:
		end = hit.position
		var victim := hit.collider as HoverJet
		if victim:
			Sound.play_at("bullet_hit", end, 0.0, randf_range(0.85, 1.2), 14.0)
			Effects.sparks(world, end, victim.spec.color, 12, 20.0, 0.35, -dir, 70.0, -6.0)
			Effects.flash(world, end, Color(1.0, 0.4, 0.2), 0.7, 0.08)
			victim.apply_damage(gun_damage * car.spec.gun_damage_mult, car)
			victim.apply_impulse(dir * gun_hit_impulse, end - victim.global_position)
		elif randf() < 0.3:
			Sound.play_at("bullet_ricochet", end, 0.0, randf_range(0.8, 1.3))
		else:
			Effects.sparks(world, end, bolt, 6, 14.0, 0.25, Vector3.UP, 80.0, -10.0, 0.4)
	# Neon bolt: a short glowing dart near the muzzle plus a faint full-length line.
	var bolt_end := muzzle.lerp(end, minf(1.0, 18.0 / maxf(muzzle.distance_to(end), 0.01)))
	Effects.tracer(world, muzzle, bolt_end, bolt, 0.12, 0.05)
	Effects.tracer(world, muzzle, end, bolt, 0.04, 0.04)


# --- Hookshot -------------------------------------------------------------------

func _fire_hook(backward := false) -> void:
	var target := find_target(car, hook_range, hook_cone_deg, backward)
	car._sfx("hook_fire", car.global_position)
	_release_hook()
	var hook := VenomHook.new()
	hook.owner_jet = car
	hook.target = target
	hook.backward = backward
	hook.color = PowerUp.color_of(PowerUp.Type.HOOKSHOT)
	hook.finished.connect(func() -> void:
		hook_target = null
		_hook = null)
	hook_target = target
	_hook = hook
	car.get_parent().add_child(hook)


func _release_hook() -> void:
	hook_target = null
	if _hook and is_instance_valid(_hook):
		_hook.queue_free()
	_hook = null


# --- Missile --------------------------------------------------------------------

func _fire_missile(backward := false) -> void:
	var missile := Missile.new()
	missile.shooter = car
	missile.target = find_target(car, missile_lock_range, missile_lock_cone_deg, backward)
	car.get_parent().add_child(missile)
	if backward:
		missile.global_position = car.tail_point(0.0, 0.9)
		missile.velocity = car.global_basis.z * 35.0 + Vector3.UP * 2.0
	else:
		missile.global_position = car.nose_point(0.0, 0.9)
		missile.velocity = -car.global_basis.z * maxf(car.forward_speed + 25.0, 40.0) + Vector3.UP * 2.0
	car._sfx("missile_launch", missile.global_position)
