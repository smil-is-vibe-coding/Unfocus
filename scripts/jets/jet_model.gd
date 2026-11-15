class_name JetModel
extends RefCounted
## Builds a low-poly, flat-shaded jet mesh from a JetSpec: pointed fuselage,
## canopy, swept wings (+ optional canards), tail fins and glowing engines.
## Nose points to -Z (Godot forward).

const BODY_SHADER := preload("res://shaders/jet_body.gdshader")


## Returns { "root": Node3D, "exhausts": Array[Vector3], "exhaust_material": StandardMaterial3D }
static func build(spec: JetSpec) -> Dictionary:
	var root := Node3D.new()
	root.name = "Model"

	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)

	var L := spec.length
	var w := spec.body_width
	var h := spec.body_height
	var z_nose := -L * 0.5
	var z_front := z_nose + L * spec.nose_ratio
	var z_mid := z_front + (L * 0.5 - z_front) * 0.35
	var z_tail := L * 0.5

	# --- Fuselage: nose tip -> three hexagonal rings -> tail cap ---
	var r_front := _ring(z_front, w * 0.75, h * 0.8)
	var r_mid := _ring(z_mid, w, h)
	var r_tail := _ring(z_tail, w * 0.8, h * 0.75)
	var nose := Vector3(0, -h * 0.15, z_nose)
	for i in 6:
		var j := (i + 1) % 6
		_tri(body, nose, r_front[i], r_front[j], Vector3(0, 0, z_front))
		_quad(body, r_front[i], r_front[j], r_mid[j], r_mid[i], Vector3(0, 0, (z_front + z_mid) * 0.5))
		_quad(body, r_mid[i], r_mid[j], r_tail[j], r_tail[i], Vector3(0, 0, (z_mid + z_tail) * 0.5))
		_tri(body, Vector3(0, 0, z_tail), r_tail[i], r_tail[j], Vector3(0, 0, z_tail - 1.0))

	# --- Canopy: a faceted glass wedge on top ---
	var c_front := Vector3(0, h * 0.75, z_front - L * 0.06)
	var c_back := Vector3(0, h * 0.95, z_mid + L * 0.12)
	var ca := [Vector3(-w * 0.42, h * 0.82, z_front + 0.2), Vector3(0, h * 1.5, z_front + 0.35), Vector3(w * 0.42, h * 0.82, z_front + 0.2)]
	var cb := [Vector3(-w * 0.42, h * 0.9, z_mid), Vector3(0, h * 1.45, z_mid - 0.1), Vector3(w * 0.42, h * 0.9, z_mid)]
	var c_ref := Vector3(0, h * 0.9, (z_front + z_mid) * 0.5)
	for i in 2:
		_tri(glass, c_front, ca[i], ca[i + 1], c_ref)
		_quad(glass, ca[i], ca[i + 1], cb[i + 1], cb[i], c_ref)
		_tri(glass, c_back, cb[i], cb[i + 1], c_ref)

	# --- Wings ---
	var edges: Array = []  # [from, to] pairs that get neon strips
	for side in [-1.0, 1.0]:
		_wing(body, edges, side, w * 0.85, spec.wing_span * 0.5, spec.wing_z, spec.wing_root_chord,
				spec.wing_tip_chord, spec.wing_sweep, -h * 0.1, spec.wing_dihedral, 0.12)
		if spec.canards:
			_wing(body, edges, side, w * 0.7, w * 0.7 + spec.wing_span * 0.16, z_front + 0.35, 0.8,
					0.3, 0.35, 0.0, 0.05, 0.06)

	# --- Tail fins ---
	if spec.fin_count == 1:
		_fin(body, edges, 0.0, 0.0, h, z_tail, spec.fin_height, L)
	elif spec.fin_count == 2:
		for side in [-1.0, 1.0]:
			_fin(body, edges, side * w * 0.7, side * spec.fin_height * 0.35, h * 0.8, z_tail, spec.fin_height, L)

	var mat := ShaderMaterial.new()
	mat.shader = BODY_SHADER
	mat.set_shader_parameter("glow_color", spec.color)
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = body.commit()
	body_mi.material_override = mat
	root.add_child(body_mi)

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.02, 0.03, 0.05)
	glass_mat.metallic = 1.0
	glass_mat.roughness = 0.05
	glass_mat.emission_enabled = true
	glass_mat.emission = spec.accent
	glass_mat.emission_energy_multiplier = 0.6
	var glass_mi := MeshInstance3D.new()
	glass_mi.name = "Canopy"
	glass_mi.mesh = glass.commit()
	glass_mi.material_override = glass_mat
	root.add_child(glass_mi)

	# Neon edge strips along wing leading edges and fins.
	var neon := StandardMaterial3D.new()
	neon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon.albedo_color = Color(spec.color.r * 2.5, spec.color.g * 2.5, spec.color.b * 2.5)
	for e in edges:
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, (e[1] - e[0]).length())
		box.material = neon
		strip.mesh = box
		strip.transform = Effects.beam_transform(e[0], e[1])
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(strip)

	# --- Engines with glowing exhausts ---
	var exhaust_mat := StandardMaterial3D.new()
	exhaust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	exhaust_mat.albedo_color = Color(spec.accent.r * 3.0, spec.accent.g * 3.0, spec.accent.b * 3.0)
	var housing_mat := ShaderMaterial.new()
	housing_mat.shader = BODY_SHADER
	housing_mat.set_shader_parameter("glow_color", spec.accent)
	var exhausts: Array[Vector3] = []
	for x in _engine_xs(spec.engine_count, w):
		var r := spec.engine_radius
		var housing := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = r * 0.85
		cyl.bottom_radius = r
		cyl.height = 1.3
		cyl.radial_segments = 8
		cyl.rings = 1
		cyl.material = housing_mat
		housing.mesh = cyl
		housing.rotation.x = PI / 2.0  # Cylinder axis Y -> Z.
		housing.position = Vector3(x, -h * 0.05, z_tail - 0.45)
		root.add_child(housing)

		var flame := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r * 0.8
		sphere.height = r * 1.6
		sphere.radial_segments = 10
		sphere.rings = 5
		sphere.material = exhaust_mat
		flame.mesh = sphere
		flame.scale = Vector3(1, 1, 1.8)
		flame.position = Vector3(x, -h * 0.05, z_tail + 0.25)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flame)
		exhausts.append(flame.position + Vector3(0, 0, r))

	return {"root": root, "exhausts": exhausts, "exhaust_material": exhaust_mat}


static func _engine_xs(count: int, w: float) -> Array[float]:
	match count:
		1:
			return [0.0]
		3:
			return [-w * 0.8, 0.0, w * 0.8]
		_:
			return [-w * 0.6, w * 0.6]


## Hexagonal cross-section ring at depth z.
static func _ring(z: float, w: float, h: float) -> Array[Vector3]:
	return [
		Vector3(0, h, z), Vector3(w, h * 0.25, z), Vector3(w * 0.7, -h * 0.55, z),
		Vector3(0, -h * 0.7, z), Vector3(-w * 0.7, -h * 0.55, z), Vector3(-w, h * 0.25, z),
	]


## Thin swept wing (a slab), mirrored by `side`.
static func _wing(st: SurfaceTool, edges: Array, side: float, root_x: float, tip_x: float, z_centre: float,
		root_chord: float, tip_chord: float, sweep: float, y: float, dihedral: float, thickness: float) -> void:
	var rf := Vector3(root_x * side, y, z_centre - root_chord * 0.5)
	var rb := Vector3(root_x * side, y, z_centre + root_chord * 0.5)
	var tf := Vector3(tip_x * side, y + dihedral, rf.z + sweep)
	var tb := Vector3(tip_x * side, y + dihedral, tf.z + tip_chord)
	_slab(st, [rf, tf, tb, rb], Vector3.UP, thickness)
	edges.append([rf + Vector3.UP * thickness * 0.5, tf + Vector3.UP * thickness * 0.3])


static func _fin(st: SurfaceTool, edges: Array, x: float, cant: float, base_y: float, z_tail: float, height: float, length: float) -> void:
	var bf := Vector3(x, base_y * 0.7, z_tail - length * 0.3)
	var bb := Vector3(x, base_y * 0.7, z_tail - 0.05)
	var tb := Vector3(x + cant, base_y + height, z_tail + 0.15)
	var tf := Vector3(x + cant, base_y + height, z_tail - length * 0.1)
	_slab(st, [bf, tf, tb, bb], Vector3.RIGHT, 0.07)
	edges.append([bf, tf])


## Extrudes a flat quad (p0..p3, in order) by `thickness` along `dir` into a closed slab.
static func _slab(st: SurfaceTool, quad: Array, dir: Vector3, thickness: float) -> void:
	var off := dir.normalized() * thickness * 0.5
	var top: Array[Vector3] = []
	var bot: Array[Vector3] = []
	var centre := Vector3.ZERO
	for p: Vector3 in quad:
		top.append(p + off)
		bot.append(p - off)
		centre += p
	centre /= 4.0
	_quad(st, top[0], top[1], top[2], top[3], centre)
	_quad(st, bot[0], bot[1], bot[2], bot[3], centre)
	for i in 4:
		var j := (i + 1) % 4
		_quad(st, top[i], top[j], bot[j], bot[i], centre)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ref: Vector3) -> void:
	_tri(st, a, b, c, ref)
	_tri(st, a, c, d, ref)


## Adds a flat-shaded triangle wound so its normal faces away from `ref` (the part's interior).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	var centroid := (a + b + c) / 3.0
	if n.dot(centroid - ref) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)
