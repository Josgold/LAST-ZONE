extends Node3D

const MOVE_SPEED := 6.0
const SPRINT_SPEED := 8.5
const JUMP_SPEED := 5.0
const GRAVITY := 14.0
const LOOK_SENSITIVITY := 0.005

var player: CharacterBody3D
var move_direction := Vector2.ZERO
var jump_requested := false
var sprint_requested := false
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
var scene_environment: Environment
var sunlight: DirectionalLight3D
var graphics_quality := 1
var graphics_button: Button
var player_visual_root: Node3D
var animation_clock := 0.0
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var joystick_knob: Panel
var joystick_active := false

func _ready() -> void:
    _make_world()
    _make_player()
    _make_mobile_controls()
    _make_gameplay_systems()

func _process(delta: float) -> void:
    animation_clock += delta
    if camera_pivot != null and player != null:
        var camera_target := player.global_position + Vector3(0, 1.3, 0)
        camera_pivot.global_position = camera_pivot.global_position.lerp(
            camera_target,
            1.0 - exp(-9.0 * delta)
        )
    if player_visual_root != null and player != null:
        var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
        var movement_amount := clampf(horizontal_speed / MOVE_SPEED, 0.0, 1.0)
        var bob_speed := 10.0 if movement_amount > 0.1 else 2.2
        var bob_amount := 0.012 + (0.055 * movement_amount)
        player_visual_root.position.y = sin(animation_clock * bob_speed) * bob_amount
        player_visual_root.rotation.z = -player.velocity.x * 0.012
        var gait := sin(animation_clock * 10.0) * movement_amount * 0.48
        if left_arm_pivot != null:
            left_arm_pivot.rotation.x = -gait
        if right_arm_pivot != null:
            right_arm_pivot.rotation.x = gait
        if left_leg_pivot != null:
            left_leg_pivot.rotation.x = gait
        if right_leg_pivot != null:
            right_leg_pivot.rotation.x = -gait

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

    var current_speed := SPRINT_SPEED if sprint_requested or Input.is_action_pressed('sprint') else MOVE_SPEED
    player.velocity.x = direction.x * current_speed
    player.velocity.z = direction.z * current_speed

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
    scene_environment = Environment.new()
    var world_environment := scene_environment
    world_environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.08, 0.20, 0.38)
    sky_material.sky_horizon_color = Color(0.55, 0.70, 0.78)
    sky_material.ground_bottom_color = Color(0.08, 0.12, 0.12)
    sky_material.ground_horizon_color = Color(0.30, 0.40, 0.34)
    sky_material.sun_angle_max = 18.0
    sky_material.sun_curve = 0.12
    sky.sky_material = sky_material
    world_environment.sky = sky
    world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world_environment.ambient_light_color = Color(0.66, 0.76, 0.88)
    world_environment.ambient_light_energy = 0.9
    world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.fog_enabled = true
    world_environment.fog_light_color = Color(0.52, 0.66, 0.72)
    world_environment.fog_density = 0.0018
    world_environment.ssao_enabled = true
    world_environment.ssao_radius = 2.0
    world_environment.ssao_intensity = 1.2
    environment_node.environment = world_environment
    add_child(environment_node)

    sunlight = DirectionalLight3D.new()
    var sun := sunlight
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 65.0
    add_child(sun)

    var ocean := MeshInstance3D.new()
    var ocean_mesh := PlaneMesh.new()
    ocean_mesh.size = Vector2(150, 150)
    ocean.mesh = ocean_mesh
    ocean.position.y = -1.15
    var ocean_material := StandardMaterial3D.new()
    ocean_material.albedo_color = Color(0.025, 0.20, 0.34)
    ocean_material.roughness = 0.22
    ocean_material.metallic = 0.12
    ocean_material.specular = 0.75
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
    island_material.albedo_color = Color(0.24, 0.48, 0.22)
    island_material.roughness = 1.0
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
    for i in range(tree_positions.size()):
        var tree_scale := 0.82 + float(i % 4) * 0.12
        _add_tree(tree_positions[i], tree_scale)

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
    _make_landscape_details()
    _make_island_landmarks()

func _make_island_landmarks() -> void:
    _add_landmark("LOOKOUT", Vector3(-17, 0, -8), Color(0.86, 0.78, 0.38))
    _add_landmark("SUPPLY DEPOT", Vector3(10, 0, 8), Color(0.48, 0.78, 0.48))
    _add_landmark("LANDING PAD", Vector3(0, 0, 16), Color(0.82, 0.82, 0.66))

func _add_landmark(label_text: String, landmark_position: Vector3, marker_color: Color) -> void:
    var marker := Node3D.new()
    marker.name = label_text.replace(" ", "_") + "_Marker"
    marker.position = landmark_position
    add_child(marker)
    _add_detail_box(marker, Vector3(0, 1.25, 0), Vector3(0.16, 2.5, 0.16), Color(0.20, 0.23, 0.20))
    _add_detail_box(marker, Vector3(0, 2.45, 0), Vector3(0.72, 0.28, 0.18), marker_color)
    var sign := Label3D.new()
    sign.text = label_text
    sign.position = Vector3(0, 2.85, 0)
    sign.font_size = 32
    sign.pixel_size = 0.012
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.modulate = Color(0.96, 0.95, 0.82)
    marker.add_child(sign)

func _make_landscape_details() -> void:
    # Small shrubs and grass clumps add texture without expensive high-poly assets.
    var shrub_positions := [
        Vector3(-25, 0, -5), Vector3(-22, 0, 18), Vector3(-8, 0, 24),
        Vector3(8, 0, 25), Vector3(25, 0, 16), Vector3(26, 0, -12),
        Vector3(-25, 0, -17), Vector3(4, 0, -26), Vector3(20, 0, -23),
        Vector3(-7, 0, 20), Vector3(25, 0, 3), Vector3(-27, 0, 5)
    ]
    for shrub_position in shrub_positions:
        _add_shrub(shrub_position)

    # A sandy shoreline strip makes the island edge easier to read.
    var shore := MeshInstance3D.new()
    var shore_mesh := CylinderMesh.new()
    shore_mesh.top_radius = 33.0
    shore_mesh.bottom_radius = 34.0
    shore_mesh.height = 0.22
    shore.mesh = shore_mesh
    shore.position.y = -0.88
    var shore_material := StandardMaterial3D.new()
    shore_material.albedo_color = Color(0.66, 0.56, 0.36)
    shore_material.roughness = 1.0
    shore.material_override = shore_material
    add_child(shore)

    # Sparse grass tufts and small stones create ground variation at low cost.
    var grass_positions := [
        Vector3(-28, 0, -10), Vector3(-24, 0, 12), Vector3(-16, 0, 23),
        Vector3(-8, 0, -27), Vector3(2, 0, -28), Vector3(12, 0, -25),
        Vector3(27, 0, -18), Vector3(28, 0, 8), Vector3(18, 0, 25),
        Vector3(6, 0, 27), Vector3(-15, 0, -24), Vector3(-27, 0, 2),
        Vector3(24, 0, 22), Vector3(-2, 0, 24), Vector3(14, 0, -27),
        Vector3(-29, 0, 17), Vector3(29, 0, -2), Vector3(-19, 0, -18)
    ]
    for i in range(grass_positions.size()):
        _add_grass_clump(grass_positions[i], 0.75 + float(i % 4) * 0.12)

func _add_grass_clump(grass_position: Vector3, tuft_scale: float) -> void:
    var clump := Node3D.new()
    clump.position = grass_position
    add_child(clump)
    for blade_index in range(3):
        var blade := MeshInstance3D.new()
        var blade_mesh := BoxMesh.new()
        blade_mesh.size = Vector3(0.10, 0.48, 0.07)
        blade.mesh = blade_mesh
        blade.position = Vector3(float(blade_index - 1) * 0.13, 0.22, 0.0)
        blade.rotation.z = deg_to_rad(float(blade_index - 1) * 17.0)
        blade.scale = Vector3.ONE * tuft_scale
        var blade_material := StandardMaterial3D.new()
        blade_material.albedo_color = Color(0.18 + blade_index * 0.025, 0.34 + blade_index * 0.025, 0.12)
        blade_material.roughness = 1.0
        blade.material_override = blade_material
        clump.add_child(blade)

func _add_shrub(shrub_position: Vector3) -> void:
    var shrub := Node3D.new()
    shrub.position = shrub_position
    add_child(shrub)
    for i in range(3):
        var leaf := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 0.65
        leaf_mesh.height = 0.9
        leaf.mesh = leaf_mesh
        leaf.position = Vector3(float(i - 1) * 0.42, 0.48, 0.0)
        leaf.scale = Vector3(1.0, 0.8, 1.0)
        var leaf_material := StandardMaterial3D.new()
        leaf_material.albedo_color = Color(0.10 + i * 0.015, 0.28 + i * 0.02, 0.11)
        leaf_material.roughness = 1.0
        leaf.material_override = leaf_material
        shrub.add_child(leaf)

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

    # Layered roof trim gives each structure a clearer silhouette.
    _add_detail_box(building, Vector3(0, building_size.y / 2.0 + 0.12, 0), Vector3(building_size.x + 0.35, 0.24, building_size.z + 0.35), Color(0.20, 0.23, 0.21))
    _add_detail_box(building, Vector3(0, building_size.y / 2.0 + 0.28, 0), Vector3(building_size.x + 0.12, 0.10, building_size.z + 0.12), Color(0.29, 0.32, 0.28))
    # Front fascia, corner supports and a visible entrance step.
    for side_x in [-1.0, 1.0]:
        _add_detail_box(building, Vector3(side_x * (building_size.x / 2.0 - 0.16), 0, building_size.z / 2.0 + 0.08), Vector3(0.22, building_size.y, 0.22), Color(0.24, 0.27, 0.23))
    _add_detail_box(building, Vector3(0, -building_size.y / 2.0 + 0.08, building_size.z / 2.0 + 0.35), Vector3(1.5, 0.16, 0.65), Color(0.30, 0.31, 0.28))
    _add_detail_box(building, Vector3(0, -building_size.y / 2.0 + 0.95, building_size.z / 2.0 + 0.025), Vector3(1.1, 1.9, 0.08), Color(0.12, 0.14, 0.13))

    var window_color := Color(0.12, 0.22, 0.25)
    var window_width := minf(1.1, building_size.x * 0.18)
    var window_y := -building_size.y / 2.0 + 1.9
    _add_detail_box(building, Vector3(-building_size.x * 0.27, window_y, building_size.z / 2.0 + 0.035), Vector3(window_width, 0.75, 0.08), window_color)
    _add_detail_box(building, Vector3(building_size.x * 0.27, window_y, building_size.z / 2.0 + 0.035), Vector3(window_width, 0.75, 0.08), window_color)
    # Window frames and a subtle horizontal wall stripe.
    for side_x in [-1.0, 1.0]:
        var window_x := side_x * building_size.x * 0.27
        _add_detail_box(building, Vector3(window_x, window_y, building_size.z / 2.0 + 0.09), Vector3(window_width + 0.14, 0.10, 0.06), Color(0.18, 0.20, 0.18))
        _add_detail_box(building, Vector3(window_x, window_y + 0.38, building_size.z / 2.0 + 0.09), Vector3(0.10, 0.82, 0.06), Color(0.18, 0.20, 0.18))
    _add_detail_box(building, Vector3(0, -building_size.y / 2.0 + 0.35, -building_size.z / 2.0 - 0.025), Vector3(building_size.x * 0.82, 0.12, 0.06), Color(0.25, 0.29, 0.24))

func _add_detail_box(parent: Node3D, local_position: Vector3, box_size: Vector3, color: Color) -> void:
    var detail := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    detail.mesh = mesh
    detail.position = local_position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    detail.material_override = material
    parent.add_child(detail)

func _add_tree(tree_position: Vector3, tree_scale: float = 1.0) -> void:
    var tree_root := Node3D.new()
    tree_root.position = tree_position
    tree_root.scale = Vector3.ONE * tree_scale
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

    # Three overlapping canopy forms create a fuller, varied low-poly silhouette.
    var canopy_colors := [
        Color(0.07, 0.27, 0.11),
        Color(0.09, 0.32, 0.13),
        Color(0.12, 0.35, 0.15)
    ]
    var canopy_positions := [
        Vector3(0, 2.8, 0),
        Vector3(-0.62, 2.55, 0.12),
        Vector3(0.58, 2.62, -0.10)
    ]
    for canopy_index in range(3):
        var leaves := MeshInstance3D.new()
        var leaves_mesh := SphereMesh.new()
        leaves_mesh.radius = 1.0 if canopy_index == 0 else 0.78
        leaves_mesh.height = 1.8 if canopy_index == 0 else 1.45
        leaves.mesh = leaves_mesh
        leaves.position = canopy_positions[canopy_index]
        var leaves_material := StandardMaterial3D.new()
        leaves_material.albedo_color = canopy_colors[canopy_index]
        leaves_material.roughness = 1.0
        leaves.material_override = leaves_material
        tree_root.add_child(leaves)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.2, 0)

    player_visual_root = Node3D.new()
    player_visual_root.name = "Visuals"
    player.add_child(player_visual_root)

    var body_mesh := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.42
    capsule_mesh.height = 1.8
    body_mesh.mesh = capsule_mesh
    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = Color(0.16, 0.25, 0.14)
    body_material.roughness = 0.92
    body_mesh.material_override = body_material
    player_visual_root.add_child(body_mesh)

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
    player_visual_root.add_child(head)

    var backpack := MeshInstance3D.new()
    var pack_mesh := BoxMesh.new()
    pack_mesh.size = Vector3(0.58, 0.72, 0.30)
    backpack.mesh = pack_mesh
    backpack.position = Vector3(0, 0.12, 0.42)
    var pack_material := StandardMaterial3D.new()
    pack_material.albedo_color = Color(0.10, 0.17, 0.11)
    pack_material.roughness = 0.95
    backpack.material_override = pack_material
    player_visual_root.add_child(backpack)

    # Additional low-poly character pieces: helmet, chest vest, shoulder pads,
    # belt and boots. These are visual-only and keep the temporary model lightweight.
    var helmet := MeshInstance3D.new()
    var helmet_mesh := SphereMesh.new()
    helmet_mesh.radius = 0.32
    helmet_mesh.height = 0.34
    helmet.mesh = helmet_mesh
    helmet.position = Vector3(0, 1.32, 0)
    helmet.scale = Vector3(1.0, 0.72, 1.0)
    var helmet_material := StandardMaterial3D.new()
    helmet_material.albedo_color = Color(0.20, 0.27, 0.17)
    helmet_material.roughness = 0.9
    helmet.material_override = helmet_material
    player_visual_root.add_child(helmet)

    var vest := MeshInstance3D.new()
    var vest_mesh := BoxMesh.new()
    vest_mesh.size = Vector3(0.78, 0.78, 0.48)
    vest.mesh = vest_mesh
    vest.position = Vector3(0, 0.10, -0.02)
    var vest_material := StandardMaterial3D.new()
    vest_material.albedo_color = Color(0.28, 0.31, 0.20)
    vest_material.roughness = 0.95
    vest.material_override = vest_material
    player_visual_root.add_child(vest)

    for side_x in [-1.0, 1.0]:
        var shoulder := MeshInstance3D.new()
        var shoulder_mesh := SphereMesh.new()
        shoulder_mesh.radius = 0.23
        shoulder_mesh.height = 0.40
        shoulder.mesh = shoulder_mesh
        shoulder.position = Vector3(side_x * 0.43, 0.48, 0)
        shoulder.scale = Vector3(1.0, 0.85, 1.0)
        shoulder.material_override = vest_material
        player_visual_root.add_child(shoulder)

        var boot := MeshInstance3D.new()
        var boot_mesh := BoxMesh.new()
        boot_mesh.size = Vector3(0.34, 0.30, 0.52)
        boot.mesh = boot_mesh
        boot.position = Vector3(side_x * 0.22, -0.72, -0.08)
        var boot_material := StandardMaterial3D.new()
        boot_material.albedo_color = Color(0.13, 0.14, 0.12)
        boot.material_override = boot_material
        player_visual_root.add_child(boot)

    # Separate low-poly limbs give the avatar a clearer human silhouette.
    left_arm_pivot = _make_character_limb(
        Vector3(-0.46, 0.48, 0), Vector3(0.0, -0.34, 0),
        Vector3(0.30, 0.78, 0.30), Color(0.22, 0.28, 0.18), "LeftArm"
    )
    right_arm_pivot = _make_character_limb(
        Vector3(0.46, 0.48, 0), Vector3(0.0, -0.34, 0),
        Vector3(0.30, 0.78, 0.30), Color(0.22, 0.28, 0.18), "RightArm"
    )
    left_leg_pivot = _make_character_limb(
        Vector3(-0.21, -0.42, 0), Vector3(0.0, -0.29, 0),
        Vector3(0.36, 0.76, 0.36), Color(0.18, 0.22, 0.16), "LeftLeg"
    )
    right_leg_pivot = _make_character_limb(
        Vector3(0.21, -0.42, 0), Vector3(0.0, -0.29, 0),
        Vector3(0.36, 0.76, 0.36), Color(0.18, 0.22, 0.16), "RightLeg"
    )

    var belt := MeshInstance3D.new()
    var belt_mesh := BoxMesh.new()
    belt_mesh.size = Vector3(0.72, 0.12, 0.50)
    belt.mesh = belt_mesh
    belt.position = Vector3(0, -0.20, -0.01)
    var belt_material := StandardMaterial3D.new()
    belt_material.albedo_color = Color(0.12, 0.14, 0.11)
    belt.material_override = belt_material
    player_visual_root.add_child(belt)

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
    camera.fov = 76.0
    camera.near = 0.08
    camera.far = 180.0
    camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
    camera_pivot.add_child(camera)
    camera.current = true

    _setup_input()

func _make_character_limb(pivot_position: Vector3, mesh_position: Vector3, mesh_size: Vector3, limb_color: Color, limb_name: String) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = limb_name + "Pivot"
    pivot.position = pivot_position
    player_visual_root.add_child(pivot)

    var limb := MeshInstance3D.new()
    var limb_mesh := CapsuleMesh.new()
    limb_mesh.radius = mesh_size.x * 0.5
    limb_mesh.height = mesh_size.y
    limb.mesh = limb_mesh
    limb.position = mesh_position
    var limb_material := StandardMaterial3D.new()
    limb_material.albedo_color = limb_color
    limb_material.roughness = 0.94
    limb.material_override = limb_material
    pivot.add_child(limb)
    return pivot

func _setup_input() -> void:
    var actions := {
        "interact": KEY_E,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "jump": KEY_SPACE,
        "sprint": KEY_SHIFT
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

    # Virtual movement stick: drag inside the base to move in any direction.
    var joystick := Panel.new()
    joystick.name = "MovementJoystick"
    joystick.anchor_left = 0.035
    joystick.anchor_top = 0.70
    joystick.anchor_right = 0.035
    joystick.anchor_bottom = 0.70
    joystick.offset_right = 154
    joystick.offset_bottom = 154
    joystick.mouse_filter = Control.MOUSE_FILTER_STOP
    var joystick_style := StyleBoxFlat.new()
    joystick_style.bg_color = Color(0.04, 0.07, 0.07, 0.62)
    joystick_style.border_color = Color(0.82, 0.88, 0.78, 0.85)
    joystick_style.set_border_width_all(3)
    joystick_style.set_corner_radius_all(77)
    joystick.add_theme_stylebox_override("panel", joystick_style)
    joystick.gui_input.connect(_on_joystick_gui_input)
    layer.add_child(joystick)

    joystick_knob = Panel.new()
    joystick_knob.name = "JoystickKnob"
    joystick_knob.position = Vector2(48, 48)
    joystick_knob.size = Vector2(58, 58)
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var knob_style := StyleBoxFlat.new()
    knob_style.bg_color = Color(0.68, 0.78, 0.61, 0.92)
    knob_style.border_color = Color(0.94, 0.96, 0.87, 0.95)
    knob_style.set_border_width_all(2)
    knob_style.set_corner_radius_all(29)
    joystick_knob.add_theme_stylebox_override("panel", knob_style)
    joystick.add_child(joystick_knob)

    var jump_button := _make_action_button(layer, "JUMP", Vector2(0.855, 0.79), Vector2(0.99, 0.96), Color(0.78, 0.67, 0.32))
    jump_button.pressed.connect(func(): jump_requested = true)

    var sprint_button := _make_action_button(layer, "SPRINT", Vector2(0.72, 0.64), Vector2(0.87, 0.80), Color(0.33, 0.58, 0.43))
    sprint_button.button_down.connect(func(): sprint_requested = true)
    sprint_button.button_up.connect(func(): sprint_requested = false)

    var interact_button := _make_action_button(layer, "USE", Vector2(0.855, 0.59), Vector2(0.99, 0.75), Color(0.34, 0.52, 0.70))
    interact_button.pressed.connect(_try_interact)

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

    var hint := Label.new()
    hint.text = "DRAG RIGHT SIDE TO LOOK AROUND"
    hint.anchor_left = 0.30
    hint.anchor_top = 0.04
    hint.anchor_right = 0.76
    hint.anchor_bottom = 0.12
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(hint)

    graphics_button = Button.new()
    graphics_button.text = "GFX: BALANCED"
    graphics_button.anchor_left = 0.79
    graphics_button.anchor_top = 0.04
    graphics_button.anchor_right = 0.98
    graphics_button.anchor_bottom = 0.13
    graphics_button.pressed.connect(_cycle_graphics_quality)
    layer.add_child(graphics_button)
    _apply_graphics_quality()

func _make_action_button(parent: Control, label_text: String, top_left: Vector2, bottom_right: Vector2, button_color: Color) -> Button:
    var button := Button.new()
    button.text = label_text
    button.anchor_left = top_left.x
    button.anchor_top = top_left.y
    button.anchor_right = bottom_right.x
    button.anchor_bottom = bottom_right.y
    button.offset_left = 0
    button.offset_top = 0
    button.offset_right = 0
    button.offset_bottom = 0
    button.add_theme_font_size_override("font_size", 16)
    button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.91))
    var normal := StyleBoxFlat.new()
    normal.bg_color = button_color.darkened(0.28)
    normal.border_color = button_color.lightened(0.28)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(42)
    normal.content_margin_left = 8.0
    normal.content_margin_right = 8.0
    normal.content_margin_top = 8.0
    normal.content_margin_bottom = 8.0
    button.add_theme_stylebox_override("normal", normal)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = button_color.lightened(0.08)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover", normal)
    parent.add_child(button)
    return button

func _on_joystick_gui_input(event: InputEvent) -> void:
    var joystick := get_node_or_null("CanvasLayer/MovementJoystick") as Control
    if joystick == null or joystick_knob == null:
        return
    var center := joystick.size * 0.5
    var radius := 48.0
    if event is InputEventScreenTouch:
        joystick_active = event.pressed
        if joystick_active:
            _update_joystick(event.position, center, radius)
        else:
            move_direction = Vector2.ZERO
            joystick_knob.position = center - joystick_knob.size * 0.5
        joystick.accept_event()
    elif event is InputEventScreenDrag and joystick_active:
        _update_joystick(event.position, center, radius)
        joystick.accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        joystick_active = event.pressed
        if joystick_active:
            _update_joystick(event.position, center, radius)
        else:
            move_direction = Vector2.ZERO
            joystick_knob.position = center - joystick_knob.size * 0.5
        joystick.accept_event()
    elif event is InputEventMouseMotion and joystick_active:
        _update_joystick(event.position, center, radius)
        joystick.accept_event()

func _update_joystick(pointer_position: Vector2, center: Vector2, radius: float) -> void:
    var offset := pointer_position - center
    if offset.length() > radius:
        offset = offset.normalized() * radius
    move_direction = Vector2(offset.x / radius, offset.y / radius)
    joystick_knob.position = center + offset - joystick_knob.size * 0.5

func _cycle_graphics_quality() -> void:
    graphics_quality = (graphics_quality + 1) % 3
    _apply_graphics_quality()

func _apply_graphics_quality() -> void:
    if scene_environment == null or sunlight == null:
        return
    if graphics_quality == 0:
        scene_environment.ssao_enabled = false
        scene_environment.fog_enabled = false
        sunlight.shadow_enabled = false
        if graphics_button != null:
            graphics_button.text = "GFX: LOW"
    elif graphics_quality == 1:
        scene_environment.ssao_enabled = false
        scene_environment.fog_enabled = true
        sunlight.shadow_enabled = true
        if graphics_button != null:
            graphics_button.text = "GFX: BALANCED"
    else:
        scene_environment.ssao_enabled = true
        scene_environment.fog_enabled = true
        sunlight.shadow_enabled = true
        if graphics_button != null:
            graphics_button.text = "GFX: HIGH"

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

    var hud_panel := Panel.new()
    hud_panel.position = Vector2(10, 68)
    hud_panel.size = Vector2(286, 126)
    var hud_style := StyleBoxFlat.new()
    hud_style.bg_color = Color(0.035, 0.055, 0.055, 0.78)
    hud_style.border_color = Color(0.48, 0.62, 0.48, 0.85)
    hud_style.set_border_width_all(1)
    hud_style.set_corner_radius_all(8)
    hud_style.content_margin_left = 8.0
    hud_style.content_margin_top = 6.0
    hud_panel.add_theme_stylebox_override("panel", hud_style)
    layer.add_child(hud_panel)

    health_label = _make_hud_label(layer, "HEALTH: 100", Vector2(20, 76))
    shield_label = _make_hud_label(layer, "SHIELD: 0", Vector2(20, 102))
    inventory_label = _make_hud_label(layer, "SUPPLY TOKENS: 0", Vector2(20, 128))
    pickup_hint = _make_hud_label(layer, "Find supplies around the outpost", Vector2(20, 158))
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
    var accent_color := Color(0.92, 0.88, 0.76)
    if item_type == "MEDKIT":
        material.albedo_color = Color(0.72, 0.22, 0.20)
        accent_color = Color(0.98, 0.90, 0.82)
    elif item_type == "SHIELD CELL":
        material.albedo_color = Color(0.18, 0.48, 0.82)
        accent_color = Color(0.70, 0.88, 1.0)
    else:
        material.albedo_color = Color(0.82, 0.68, 0.22)
        accent_color = Color(1.0, 0.91, 0.55)
    material.roughness = 0.62
    mesh_node.material_override = material
    pickup.add_child(mesh_node)
    # Bright top and side bands make each supply type readable from a distance.
    _add_detail_box(pickup, Vector3(0, 0.34, 0), Vector3(0.68, 0.08, 0.68), accent_color)
    _add_detail_box(pickup, Vector3(0, 0, 0.34), Vector3(0.12, 0.68, 0.04), accent_color)
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
