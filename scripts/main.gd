extends Node3D

const MOVE_SPEED := 6.0
const JUMP_SPEED := 5.0
const GRAVITY := 14.0
const LOOK_SENSITIVITY := 0.005

var player: CharacterBody3D
var move_direction := Vector2.ZERO
var jump_requested := false
var camera_pivot: Node3D
var mouse_look_active := false
var player_health := 100
var player_shield := 0
var supply_tokens := 0
var nearby_pickup: Area3D
var health_label: Label
var shield_label: Label
var inventory_label: Label
var pickup_hint: Label

func _ready() -> void:
    _make_world()
    _make_player()
    _make_mobile_controls()
    _make_gameplay_systems()

func _process(_delta: float) -> void:
    if camera_pivot != null and player != null:
        camera_pivot.global_position = player.global_position + Vector3(0, 1.3, 0)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _try_interact()
    if event is InputEventScreenDrag:
        var screen_size := get_viewport().get_visible_rect().size
        if event.position.x > screen_size.x * 0.42 and event.position.y < screen_size.y * 0.78:
            _rotate_camera(event.relative)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        mouse_look_active = event.pressed
    elif event is InputEventMouseMotion and mouse_look_active:
        _rotate_camera(event.relative)

func _rotate_camera(relative_motion: Vector2) -> void:
    if camera_pivot == null:
        return
    camera_pivot.rotation.y -= relative_motion.x * LOOK_SENSITIVITY
    camera_pivot.rotation.x = clampf(
        camera_pivot.rotation.x - relative_motion.y * LOOK_SENSITIVITY,
        deg_to_rad(-15.0),
        deg_to_rad(35.0)
    )

func _physics_process(delta: float) -> void:
    if player == null:
        return

    var input_vector := move_direction
    if input_vector.length() < 0.01:
        input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()
    var direction := (right * input_vector.x + forward * -input_vector.y).normalized()

    player.velocity.x = direction.x * MOVE_SPEED
    player.velocity.z = direction.z * MOVE_SPEED

    if direction.length() > 0.05:
        player.rotation.y = atan2(-direction.x, -direction.z)

    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta
    elif jump_requested or Input.is_action_just_pressed("jump"):
        player.velocity.y = JUMP_SPEED

    jump_requested = false
    player.move_and_slide()

func _make_world() -> void:
    var environment_node := WorldEnvironment.new()
    var world_environment := Environment.new()
    world_environment.background_mode = Environment.BG_SKY
    world_environment.sky = Sky.new()
    world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world_environment.ambient_light_color = Color(0.65, 0.72, 0.82)
    world_environment.ambient_light_energy = 0.8
    environment_node.environment = world_environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.light_energy = 1.2
    add_child(sun)

    var ocean := MeshInstance3D.new()
    var ocean_mesh := PlaneMesh.new()
    ocean_mesh.size = Vector2(150, 150)
    ocean.mesh = ocean_mesh
    ocean.position.y = -1.15
    var ocean_material := StandardMaterial3D.new()
    ocean_material.albedo_color = Color(0.025, 0.20, 0.34)
    ocean_material.roughness = 0.28
    ocean.material_override = ocean_material
    add_child(ocean)

    var island := StaticBody3D.new()
    island.name = "Island"
    var island_mesh := MeshInstance3D.new()
    var island_shape_mesh := CylinderMesh.new()
    island_shape_mesh.top_radius = 32.0
    island_shape_mesh.bottom_radius = 34.0
    island_shape_mesh.height = 1.0
    island_mesh.mesh = island_shape_mesh
    var island_material := StandardMaterial3D.new()
    island_material.albedo_color = Color(0.20, 0.42, 0.22)
    island_mesh.material_override = island_material
    island.add_child(island_mesh)

    var island_collision := CollisionShape3D.new()
    var island_shape := CylinderShape3D.new()
    island_shape.radius = 33.0
    island_shape.height = 1.0
    island_collision.shape = island_shape
    island.add_child(island_collision)
    island.position.y = -0.5
    add_child(island)

    var tree_positions := [
        Vector3(-18, 0, -12), Vector3(-12, 0, 16), Vector3(-4, 0, -22),
        Vector3(10, 0, -17), Vector3(19, 0, -6), Vector3(15, 0, 16),
        Vector3(-20, 0, 8), Vector3(4, 0, 21), Vector3(23, 0, 10)
    ]
    for tree_position in tree_positions:
        _add_tree(tree_position)

    for i in range(12):
        var rock_node := MeshInstance3D.new()
        var rock_mesh := SphereMesh.new()
        rock_mesh.radius = 0.8
        rock_mesh.height = 1.3
        rock_node.mesh = rock_mesh
        var rock_material := StandardMaterial3D.new()
        rock_material.albedo_color = Color(0.32, 0.34, 0.3)
        rock_node.material_override = rock_material
        rock_node.position = Vector3(float((i % 4) * 8 - 12), 0.6, float(int(i / 4) * 10 - 10))
        add_child(rock_node)

    _make_military_base()

func _make_military_base() -> void:
    # A small, non-combat military outpost that gives the island recognizable landmarks.
    _add_building("Barracks", Vector3(-10, 0, -9), Vector3(8, 3.4, 6), Color(0.34, 0.39, 0.31))
    _add_building("Hangar", Vector3(9, 0, -12), Vector3(10, 4.4, 8), Color(0.40, 0.43, 0.42))
    _add_building("Supply House", Vector3(10, 0, 8), Vector3(6, 3.0, 5), Color(0.48, 0.40, 0.29))
    _add_building("Guard House", Vector3(-15, 0, 7), Vector3(5, 2.8, 5), Color(0.38, 0.42, 0.34))
    _add_building("Workshop", Vector3(20, 0, -1), Vector3(5, 3.0, 6), Color(0.36, 0.39, 0.42))

    # A marked landing pad, supply containers, tents, perimeter fence and lamps.
    _add_detail_box(self, Vector3(0, 0.08, 16), Vector3(13, 0.16, 9), Color(0.25, 0.28, 0.25))
    _add_detail_box(self, Vector3(0, 0.17, 16), Vector3(11, 0.04, 7), Color(0.48, 0.49, 0.43))
    _add_detail_box(self, Vector3(0, 0.22, 16), Vector3(0.35, 0.05, 5), Color(0.88, 0.82, 0.28))
    _add_detail_box(self, Vector3(0, 0.22, 16), Vector3(8, 0.05, 0.35), Color(0.88, 0.82, 0.28))
    _add_supply_crate(Vector3(-4, 0, 3))
    _add_supply_crate(Vector3(-2, 0, 4))
    _add_supply_crate(Vector3(4, 0, 4))
    _add_tent(Vector3(17, 0, 15))
    _add_tent(Vector3(-23, 0, 15))
    _add_fence_line(Vector3(-24, 0, -20), Vector3(24, 0, -20), 12)
    _add_fence_line(Vector3(-24, 0, 20), Vector3(24, 0, 20), 12)
    _add_lamp(Vector3(-5, 0, -17))
    _add_lamp(Vector3(15, 0, -17))
    _add_lamp(Vector3(18, 0, 5))

    # Watchtower: a raised platform supported by four posts.
    var tower := Node3D.new()
    tower.name = "Watchtower"
    tower.position = Vector3(-17, 0, -8)
    add_child(tower)
    _add_detail_box(tower, Vector3(0, 2.5, 0), Vector3(3.2, 0.35, 3.2), Color(0.32, 0.35, 0.30))
    _add_detail_box(tower, Vector3(-1.25, 1.25, -1.25), Vector3(0.22, 2.5, 0.22), Color(0.25, 0.27, 0.24))
    _add_detail_box(tower, Vector3(1.25, 1.25, -1.25), Vector3(0.22, 2.5, 0.22), Color(0.25, 0.27, 0.24))
    _add_detail_box(tower, Vector3(-1.25, 1.25, 1.25), Vector3(0.22, 2.5, 0.22), Color(0.25, 0.27, 0.24))
    _add_detail_box(tower, Vector3(1.25, 1.25, 1.25), Vector3(0.22, 2.5, 0.22), Color(0.25, 0.27, 0.24))
    _add_detail_box(tower, Vector3(0, 3.0, 0), Vector3(3.8, 0.25, 3.8), Color(0.22, 0.25, 0.22))

    # Simple roads connect the outpost buildings.
    _add_detail_box(self, Vector3(0, 0.035, -3), Vector3(3.2, 0.07, 23), Color(0.16, 0.17, 0.16))
    _add_detail_box(self, Vector3(0, 0.04, -12), Vector3(25, 0.08, 3.0), Color(0.16, 0.17, 0.16))


func _add_supply_crate(crate_position: Vector3) -> void:
    var crate := StaticBody3D.new()
    crate.position = crate_position + Vector3(0, 0.55, 0)
    add_child(crate)
    _add_detail_box(crate, Vector3.ZERO, Vector3(1.2, 1.1, 1.2), Color(0.42, 0.29, 0.15))
    _add_detail_box(crate, Vector3(0, 0, 0.62), Vector3(1.25, 0.12, 0.08), Color(0.68, 0.55, 0.28))
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.2, 1.1, 1.2)
    shape.shape = box
    crate.add_child(shape)

func _add_tent(tent_position: Vector3) -> void:
    var tent := Node3D.new()
    tent.position = tent_position
    add_child(tent)
    _add_detail_box(tent, Vector3(0, 0.8, 0), Vector3(3.2, 1.6, 2.5), Color(0.30, 0.36, 0.27))
    var roof := MeshInstance3D.new()
    var roof_mesh := PrismMesh.new()
    roof_mesh.size = Vector3(3.5, 1.0, 2.8)
    roof.mesh = roof_mesh
    roof.position.y = 1.9
    var roof_material := StandardMaterial3D.new()
    roof_material.albedo_color = Color(0.22, 0.29, 0.21)
    roof.material_override = roof_material
    tent.add_child(roof)

func _add_fence_line(start: Vector3, finish: Vector3, post_count: int) -> void:
    for i in range(post_count + 1):
        var t := float(i) / float(post_count)
        var p := start.lerp(finish, t)
        _add_detail_box(self, p + Vector3(0, 0.65, 0), Vector3(0.18, 1.3, 0.18), Color(0.24, 0.26, 0.23))
    _add_detail_box(self, (start + finish) * 0.5 + Vector3(0, 0.9, 0), Vector3(start.distance_to(finish), 0.12, 0.10), Color(0.30, 0.32, 0.29))

func _add_lamp(lamp_position: Vector3) -> void:
    var lamp := Node3D.new()
    lamp.position = lamp_position
    add_child(lamp)
    _add_detail_box(lamp, Vector3(0, 1.8, 0), Vector3(0.16, 3.6, 0.16), Color(0.18, 0.20, 0.19))
    _add_detail_box(lamp, Vector3(0, 3.65, 0), Vector3(0.65, 0.16, 0.65), Color(0.85, 0.78, 0.46))

func _add_building(building_name: String, building_position: Vector3, building_size: Vector3, wall_color: Color) -> void:
    var building := StaticBody3D.new()
    building.name = building_name
    building.position = building_position + Vector3(0, building_size.y / 2.0, 0)
    add_child(building)

    var body_mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = building_size
    body_mesh.mesh = box_mesh
    var wall_material := StandardMaterial3D.new()
    wall_material.albedo_color = wall_color
    wall_material.roughness = 0.9
    body_mesh.material_override = wall_material
    building.add_child(body_mesh)

    var collision := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = building_size
    collision.shape = box_shape
    building.add_child(collision)

    _add_detail_box(building, Vector3(0, building_size.y / 2.0 + 0.12, 0), Vector3(building_size.x + 0.35, 0.24, building_size.z + 0.35), Color(0.20, 0.23, 0.21))
    _add_detail_box(building, Vector3(0, -building_size.y / 2.0 + 0.95, building_size.z / 2.0 + 0.025), Vector3(1.1, 1.9, 0.08), Color(0.12, 0.14, 0.13))

    var window_color := Color(0.12, 0.22, 0.25)
    var window_width := minf(1.1, building_size.x * 0.18)
    var window_y := -building_size.y / 2.0 + 1.9
    _add_detail_box(building, Vector3(-building_size.x * 0.27, window_y, building_size.z / 2.0 + 0.035), Vector3(window_width, 0.75, 0.08), window_color)
    _add_detail_box(building, Vector3(building_size.x * 0.27, window_y, building_size.z / 2.0 + 0.035), Vector3(window_width, 0.75, 0.08), window_color)

func _add_detail_box(parent: Node3D, local_position: Vector3, box_size: Vector3, color: Color) -> void:
    var detail := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    detail.mesh = mesh
    detail.position = local_position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    detail.material_override = material
    parent.add_child(detail)

func _add_tree(tree_position: Vector3) -> void:
    var tree_root := Node3D.new()
    tree_root.position = tree_position
    add_child(tree_root)

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.22
    trunk_mesh.bottom_radius = 0.35
    trunk_mesh.height = 2.4
    trunk.mesh = trunk_mesh
    trunk.position.y = 1.2
    var trunk_material := StandardMaterial3D.new()
    trunk_material.albedo_color = Color(0.28, 0.16, 0.08)
    trunk.material_override = trunk_material
    tree_root.add_child(trunk)

    var leaves := MeshInstance3D.new()
    var leaves_mesh := SphereMesh.new()
    leaves_mesh.radius = 1.25
    leaves_mesh.height = 2.2
    leaves.mesh = leaves_mesh
    leaves.position.y = 2.8
    var leaves_material := StandardMaterial3D.new()
    leaves_material.albedo_color = Color(0.08, 0.30, 0.12)
    leaves.material_override = leaves_material
    tree_root.add_child(leaves)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.2, 0)

    var body_mesh := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.42
    capsule_mesh.height = 1.8
    body_mesh.mesh = capsule_mesh
    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = Color(0.20, 0.30, 0.18)
    body_mesh.material_override = body_material
    player.add_child(body_mesh)

    # Simple low-poly field outfit details for the temporary player model.
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.28
    head_mesh.height = 0.56
    head.mesh = head_mesh
    head.position.y = 1.05
    var head_material := StandardMaterial3D.new()
    head_material.albedo_color = Color(0.72, 0.57, 0.42)
    head.material_override = head_material
    player.add_child(head)

    var backpack := MeshInstance3D.new()
    var pack_mesh := BoxMesh.new()
    pack_mesh.size = Vector3(0.58, 0.72, 0.30)
    backpack.mesh = pack_mesh
    backpack.position = Vector3(0, 0.12, 0.42)
    var pack_material := StandardMaterial3D.new()
    pack_material.albedo_color = Color(0.12, 0.20, 0.12)
    backpack.material_override = pack_material
    player.add_child(backpack)

    var collision := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.radius = 0.42
    capsule_shape.height = 1.8
    collision.shape = capsule_shape
    player.add_child(collision)
    add_child(player)

    camera_pivot = Node3D.new()
    camera_pivot.position = player.position + Vector3(0, 1.3, 0)
    camera_pivot.rotation.x = deg_to_rad(12.0)
    add_child(camera_pivot)

    var camera := Camera3D.new()
    camera.position = Vector3(0, 2.8, 7.5)
    camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
    camera_pivot.add_child(camera)
    camera.current = true

    _setup_input()

func _setup_input() -> void:
    var actions := {
        "interact": KEY_E,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "jump": KEY_SPACE
    }
    for action_name in actions:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        var key_event := InputEventKey.new()
        key_event.physical_keycode = actions[action_name]
        InputMap.action_add_event(action_name, key_event)

func _make_mobile_controls() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var panel := HBoxContainer.new()
    panel.anchor_left = 0.02
    panel.anchor_top = 0.72
    panel.anchor_right = 0.70
    panel.anchor_bottom = 0.96
    panel.add_theme_constant_override("separation", 6)
    layer.add_child(panel)

    _add_hold_button(panel, "LEFT", Vector2(-1, 0))
    _add_hold_button(panel, "RIGHT", Vector2(1, 0))
    _add_hold_button(panel, "FORWARD", Vector2(0, -1))
    _add_hold_button(panel, "BACK", Vector2(0, 1))

    var jump_button := Button.new()
    jump_button.text = "JUMP"
    jump_button.custom_minimum_size = Vector2(90, 64)
    jump_button.anchor_left = 0.82
    jump_button.anchor_top = 0.78
    jump_button.anchor_right = 0.98
    jump_button.anchor_bottom = 0.94
    jump_button.pressed.connect(func(): jump_requested = true)
    layer.add_child(jump_button)

    var title := Label.new()
    title.text = "LAST ZONE  |  ISLAND OUTPOST"
    title.position = Vector2(18, 14)
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.86))
    layer.add_child(title)

    var status := Label.new()
    status.text = "FIELD TEST  •  SOLO MODE"
    status.position = Vector2(18, 44)
    status.add_theme_font_size_override("font_size", 14)
    status.add_theme_color_override("font_color", Color(0.78, 0.84, 0.72))
    layer.add_child(status)

    var interact_button := Button.new()
    interact_button.text = "INTERACT"
    interact_button.custom_minimum_size = Vector2(112, 58)
    interact_button.anchor_left = 0.78
    interact_button.anchor_top = 0.63
    interact_button.anchor_right = 0.98
    interact_button.anchor_bottom = 0.75
    interact_button.pressed.connect(_try_interact)
    layer.add_child(interact_button)

    var hint := Label.new()
    hint.text = "DRAG RIGHT SIDE TO LOOK AROUND"
    hint.anchor_left = 0.42
    hint.anchor_top = 0.04
    hint.anchor_right = 0.98
    hint.anchor_bottom = 0.12
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(hint)

func _add_hold_button(parent: Control, label_text: String, direction: Vector2) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(76, 64)
    button.button_down.connect(func(): move_direction = direction)
    button.button_up.connect(func():
        if move_direction == direction:
            move_direction = Vector2.ZERO
    )
    parent.add_child(button)


func _make_gameplay_systems() -> void:
    _create_pickup("MEDKIT", Vector3(-5, 0.8, 3), "Restores 35 health")
    _create_pickup("SHIELD CELL", Vector3(2, 0.8, 5), "Adds 50 shield")
    _create_pickup("SUPPLY TOKEN", Vector3(5, 0.8, 3), "Adds 1 supply token")

    var layer := get_node_or_null("GameplayHUD") as CanvasLayer
    if layer == null:
        layer = CanvasLayer.new()
        layer.name = "GameplayHUD"
        add_child(layer)

    health_label = _make_hud_label(layer, "HEALTH: 100", Vector2(18, 76))
    shield_label = _make_hud_label(layer, "SHIELD: 0", Vector2(18, 102))
    inventory_label = _make_hud_label(layer, "SUPPLY TOKENS: 0", Vector2(18, 128))
    pickup_hint = _make_hud_label(layer, "Find supplies around the outpost", Vector2(18, 158))
    _refresh_gameplay_hud()

func _make_hud_label(parent: Control, label_text: String, label_position: Vector2) -> Label:
    var label := Label.new()
    label.text = label_text
    label.position = label_position
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.88))
    parent.add_child(label)
    return label

func _create_pickup(item_type: String, item_position: Vector3, description: String) -> void:
    var pickup := Area3D.new()
    pickup.name = item_type.replace(" ", "_")
    pickup.position = item_position
    pickup.set_meta("item_type", item_type)
    pickup.set_meta("description", description)
    pickup.collision_layer = 0
    pickup.collision_mask = 1
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.65, 0.65, 0.65)
    mesh_node.mesh = mesh
    var material := StandardMaterial3D.new()
    if item_type == "MEDKIT":
        material.albedo_color = Color(0.72, 0.22, 0.20)
    elif item_type == "SHIELD CELL":
        material.albedo_color = Color(0.18, 0.48, 0.82)
    else:
        material.albedo_color = Color(0.82, 0.68, 0.22)
    mesh_node.material_override = material
    pickup.add_child(mesh_node)
    var collision := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.8
    collision.shape = sphere
    pickup.add_child(collision)
    pickup.body_entered.connect(func(body: Node3D):
        if body == player:
            nearby_pickup = pickup
            _refresh_gameplay_hud()
    )
    pickup.body_exited.connect(func(body: Node3D):
        if body == player and nearby_pickup == pickup:
            nearby_pickup = null
            _refresh_gameplay_hud()
    )
    add_child(pickup)

func _try_interact() -> void:
    if nearby_pickup == null or not is_instance_valid(nearby_pickup):
        return
    var item_type: String = nearby_pickup.get_meta("item_type", "")
    if item_type == "MEDKIT":
        player_health = mini(100, player_health + 35)
    elif item_type == "SHIELD CELL":
        player_shield = mini(100, player_shield + 50)
    elif item_type == "SUPPLY TOKEN":
        supply_tokens += 1
    nearby_pickup.queue_free()
    nearby_pickup = null
    _refresh_gameplay_hud()

func _refresh_gameplay_hud() -> void:
    if health_label == null:
        return
    health_label.text = "HEALTH: %d" % player_health
    shield_label.text = "SHIELD: %d" % player_shield
    inventory_label.text = "SUPPLY TOKENS: %d" % supply_tokens
    if nearby_pickup != null and is_instance_valid(nearby_pickup):
        pickup_hint.text = "Nearby: %s  |  Press E or INTERACT" % nearby_pickup.get_meta("item_type", "SUPPLY")
    else:
        pickup_hint.text = "Explore the outpost to find supplies"
