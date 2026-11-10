extends Node3D

const WALK_SPEED := 3.2
const RUN_SPEED := 5.0
var player: CharacterBody3D
var camera: Camera3D
var ray: RayCast3D
var hint: Label
var score_label: Label
var score := 0
var found := 0
var finished := false
var flashlight: SpotLight3D
var reportables: Array[Dictionary] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_world()
	_build_player()
	_build_ui()
	_build_objects()
	_update_score()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0022)
		camera.rotate_x(-event.relative.y * 0.0022)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-82), deg_to_rad(82))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_report_target()
		elif event.keycode == KEY_F:
			flashlight.visible = not flashlight.visible

func _physics_process(delta: float) -> void:
	if finished:
		return
	var input_dir := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))).normalized()
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()
	_update_hint()

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	light.light_energy = 0.65
	light.shadow_enabled = false
	add_child(light)
	_box("Floor", Vector3(0, -0.15, 0), Vector3(12, 0.3, 10), Color(0.28, 0.29, 0.27))
	_box("BackWall", Vector3(0, 1.8, -5), Vector3(12, 3.6, 0.25), Color(0.57, 0.55, 0.48))
	_box("LeftWall", Vector3(-6, 1.8, 0), Vector3(0.25, 3.6, 10), Color(0.48, 0.50, 0.48))
	_box("RightWall", Vector3(6, 1.8, 0), Vector3(0.25, 3.6, 10), Color(0.48, 0.50, 0.48))
	_box("FrontLeft", Vector3(-4.4, 1.8, 5), Vector3(3.2, 3.6, 0.25), Color(0.57, 0.55, 0.48))
	_box("FrontRight", Vector3(4.4, 1.8, 5), Vector3(3.2, 3.6, 0.25), Color(0.57, 0.55, 0.48))
	_box("Ceiling", Vector3(0, 3.65, 0), Vector3(12, 0.2, 10), Color(0.38, 0.39, 0.37))
	_box("Door", Vector3(0, 1.45, 4.92), Vector3(1.8, 2.9, 0.12), Color(0.32, 0.20, 0.14))
	_box("Desk", Vector3(-2.5, 0.85, -1.5), Vector3(2.2, 0.15, 1.0), Color(0.30, 0.20, 0.13))
	_box("Board", Vector3(0, 2.1, -4.82), Vector3(3.0, 1.5, 0.08), Color(0.20, 0.26, 0.24))
	_box("Notice", Vector3(0, 2.1, -4.75), Vector3(1.8, 1.05, 0.04), Color(0.82, 0.78, 0.61))
	_text_3d("GERÇEKLİK DENETİMİ\nGÜLÜMSEMEK ZORUNLUDUR", Vector3(0, 2.1, -4.69), 0.18, Color(0.12, 0.13, 0.12))
	_box("Window", Vector3(4.0, 2.1, -4.82), Vector3(1.6, 1.4, 0.06), Color(0.10, 0.16, 0.19))

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.95, 3.2)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.62, 0)
	player.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	ray.collide_with_areas = true
	camera.add_child(ray)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.18, -0.12, -0.15)
	flashlight.spot_range = 11.0
	flashlight.spot_angle = 35.0
	flashlight.light_energy = 1.5
	flashlight.visible = false
	camera.add_child(flashlight)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8, -15)
	crosshair.add_theme_font_size_override("font_size", 25)
	layer.add_child(crosshair)
	var title := Label.new()
	title.text = "GERÇEKLİK DENETLEME MÜDÜRLÜĞÜ  /  VARDİYA 01"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.72, 0.74, 0.68))
	layer.add_child(title)
	score_label = Label.new()
	score_label.position = Vector2(24, 48)
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.76))
	layer.add_child(score_label)
	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-280, -64)
	hint.size = Vector2(560, 42)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	layer.add_child(hint)

func _build_objects() -> void:
	_box("CoffeeMug", Vector3(-2.7, 1.12, -1.5), Vector3(0.22, 0.28, 0.22), Color(0.75, 0.73, 0.63))
	_box("FileStack", Vector3(-2.2, 1.05, -1.45), Vector3(0.55, 0.12, 0.42), Color(0.36, 0.43, 0.49))
	_make_reportable("FloatingChair", Vector3(2.3, 1.45, -1.0), Vector3(0.9, 0.65, 0.9), Color(0.52, 0.23, 0.18), true, "Sandalye havada. İnsan kaynakları bunu ergonomik bulabilir.")
	_make_reportable("BrokenClock", Vector3(-4.7, 2.35, -4.65), Vector3(0.72, 0.72, 0.14), Color(0.82, 0.78, 0.62), true, "Saat 12:60 gösteriyor. Mesai süresi yeniden tanımlandı.")
	_make_reportable("SuspiciousPlant", Vector3(4.4, 0.9, 1.0), Vector3(0.55, 1.1, 0.55), Color(0.22, 0.38, 0.25), true, "Bitki sana bakıyor. Botanik biriminden onay bekleniyor.")
	_make_reportable("NormalBox", Vector3(2.4, 0.45, 1.6), Vector3(0.7, 0.7, 0.7), Color(0.55, 0.42, 0.25), false, "Bu kutu tamamen normal. Şimdilik.")

func _make_reportable(node_name: String, pos: Vector3, size: Vector3, color: Color, anomaly: bool, message: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.set_meta("is_anomaly", anomaly)
	area.set_meta("report_message", message)
	add_child(area)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color)
	area.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.15, 0.15, 0.15)
	collision.shape = shape
	area.add_child(collision)
	if node_name == "BrokenClock":
		var clock_text := Label3D.new()
		clock_text.text = "12:60"
		clock_text.position = Vector3(0, 0, 0.09)
		clock_text.font_size = 48
		clock_text.modulate = Color(0.18, 0.16, 0.13)
		area.add_child(clock_text)
	elif node_name == "SuspiciousPlant":
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.11
		eye_mesh.height = 0.22
		eye.mesh = eye_mesh
		eye.position = Vector3(0, 0.25, -0.28)
		eye.material_override = _mat(Color(0.92, 0.88, 0.72))
		area.add_child(eye)
	reportables.append({"node": area, "anomaly": anomaly, "message": message, "reported": false})

func _report_target() -> void:
	if not ray.is_colliding():
		_show_hint("Raporlanacak bir şey yok. İş disiplinini koru.")
		return
	var target: Node = ray.get_collider()
	while target != null and not target.has_meta("is_anomaly"):
		target = target.get_parent()
	if target == null:
		_show_hint("Bu nesne kurum envanterinde kayıtlı değil.")
		return
	for item in reportables:
		if item.node == target:
			if item.reported:
				_show_hint("Bu anomali zaten raporlandı. Çifte mesai yok.")
				return
			item.reported = true
			if item.anomaly:
				score += 100
				found += 1
				_show_hint("DOĞRU RAPOR +100 | " + item.message)
			else:
				score -= 25
				_show_hint("YANLIŞ RAPOR -25 | " + item.message)
			_update_score()
			if found == 3:
				finished = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_show_hint("VARDİYA TAMAMLANDI! Puan: %d | Müdürlük seninle gurur duyuyor. Muhtemelen." % score)
			return

func _update_hint() -> void:
	if ray.is_colliding():
		var target: Node = ray.get_collider()
		while target != null and not target.has_meta("is_anomaly"):
			target = target.get_parent()
		if target != null:
			hint.text = "E  /  RAPORLA"
			return
	hint.text = "Odayı incele. Şüpheli bir şey görürsen E ile raporla."

func _update_score() -> void:
	score_label.text = "DENETİM PUANI: %d     BULUNAN ANOMALİ: %d/3" % [score, found]

func _show_hint(message: String) -> void:
	hint.text = message

func _box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = pos
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _mat(color)
	body.add_child(instance)
	return instance

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _text_3d(value: String, pos: Vector3, pixel_size: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = 32
	label.pixel_size = pixel_size / 32.0
	label.modulate = color
	add_child(label)
