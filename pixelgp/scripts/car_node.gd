extends Node3D
## Visual formula car: low-poly boxes in team colors, boost flame, brake light.
## Position/rotation are driven from a CarPhysics instance each tick.

const Pix = preload("res://scripts/pixel_textures.gd")

var _mesh_root: Node3D
var _flame: MeshInstance3D
var _brake: MeshInstance3D
var _sparks: CPUParticles3D
var _impact_seen := -10.0

func build(primary: Color, secondary: Color) -> void:
	_mesh_root = Node3D.new()
	# tiny formula cars in a huge glamorous city — scale well below road width
	_mesh_root.scale = Vector3(0.62, 0.62, 0.62)
	add_child(_mesh_root)
	var p := Pix.flat_mat(primary)
	var s := Pix.flat_mat(secondary)
	var dark := Pix.flat_mat(Color(0.07, 0.07, 0.08))
	_part(Vector3(13, 2.4, 5.6), Vector3(0, 2.0, 0), p)        # body
	_part(Vector3(5, 1.7, 2.8), Vector3(8.4, 1.8, 0), p)       # nose
	_part(Vector3(2.2, 0.8, 9.6), Vector3(10.6, 1.0, 0), s)    # front wing
	_part(Vector3(2.0, 0.9, 8.6), Vector3(-7.6, 3.6, 0), s)    # rear wing
	_part(Vector3(3.6, 1.5, 2.8), Vector3(-1.0, 3.4, 0), dark) # cockpit
	var helmet := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.2
	helmet.mesh = sm
	helmet.material_override = Pix.flat_mat(Color(0.92, 0.92, 0.95))
	helmet.position = Vector3(-1.0, 4.1, 0)
	_mesh_root.add_child(helmet)
	for wx in [5.0, -5.0]:
		for wz in [4.0, -4.0]:
			_part(Vector3(3.2, 3.2, 2.0), Vector3(wx, 1.6, wz), dark)
	_flame = _part(Vector3(3.4, 1.6, 1.6), Vector3(-9.6, 2.2, 0), Pix.flat_mat(Color(1.0, 0.55, 0.1), 3.0))
	_flame.visible = false
	_brake = _part(Vector3(0.8, 1.0, 3.0), Vector3(-8.9, 2.6, 0), Pix.flat_mat(Color(1.0, 0.1, 0.05), 2.5))
	_brake.visible = false
	# wall-hit spark burst
	_sparks = CPUParticles3D.new()
	_sparks.amount = 14
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.lifetime = 0.32
	_sparks.emitting = false
	_sparks.spread = 70.0
	_sparks.direction = Vector3(0, 1, 0)
	_sparks.initial_velocity_min = 25.0
	_sparks.initial_velocity_max = 55.0
	_sparks.gravity = Vector3(0, -110, 0)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.7, 0.7, 0.7)
	spark_mesh.material = Pix.flat_mat(Color(1.0, 0.7, 0.2), 2.5)
	_sparks.mesh = spark_mesh
	_sparks.position = Vector3(0, 2.0, 0)
	add_child(_sparks)

func _part(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_mesh_root.add_child(mi)
	return mi

func sync(phys, track) -> void:
	position = phys.pos + Vector3(0, 0.3, 0)
	rotation.y = -phys.heading
	# pitch with the elevation gradient, lean into steering
	var n: int = track.n
	var i: int = phys.idx
	var ahead: Vector3 = track.samples[(i + 3) % n]
	var behind: Vector3 = track.samples[(i - 3 + n) % n]
	var dd := Vector2(ahead.x - behind.x, ahead.z - behind.z).length()
	if dd > 0.1:
		_mesh_root.rotation.z = atan2(ahead.y - behind.y, dd) * 0.8
	_flame.visible = phys.boosting
	_brake.visible = phys.braking and phys.speed > 20.0
	if phys.impact_stamp > _impact_seen and phys.impact_mag > 0.05:
		_impact_seen = phys.impact_stamp
		_sparks.restart()
