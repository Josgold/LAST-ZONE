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

func _ready() -> void:
    _make_world()
    _make_player()
    _make_mobile_controls()

func _process(_delta: float) -> void:
    if camera_pivot != null and player != null:
        camera_pivot.global_position = player.global_position + Vector3(0, 1.3, 0)

func _unhandled_input(event: InputEvent) -> void:
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
    body_material.albedo_color = Color(0.12, 0.42, 0.9)
    body_mesh.material_override = body_material
    player.add_child(body_mesh)

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
