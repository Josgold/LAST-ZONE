extends Node3D

const MOVE_SPEED := 6.0
const JUMP_SPEED := 5.0
const GRAVITY := 14.0

var player: CharacterBody3D
var move_direction := Vector2.ZERO
var jump_requested := false
var camera_pivot: Node3D

func _ready() -> void:
    _make_world()
    _make_player()
    _make_mobile_controls()

func _process(_delta: float) -> void:
    if camera_pivot != null and player != null:
        camera_pivot.global_position = player.global_position + Vector3(0, 1.3, 0)

func _physics_process(delta: float) -> void:
    if player == null:
        return

    var input_vector := move_direction
    if input_vector.length() < 0.01:
        input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    var direction := Vector3(input_vector.x, 0, input_vector.y).normalized()
    player.velocity.x = direction.x * MOVE_SPEED
    player.velocity.z = direction.z * MOVE_SPEED

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

    var ground := StaticBody3D.new()
    ground.name = "Ground"
    var ground_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(80, 80)
    ground_mesh.mesh = plane
    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color(0.18, 0.38, 0.22)
    ground_mesh.material_override = ground_material
    ground.add_child(ground_mesh)

    var ground_collision := CollisionShape3D.new()
    var ground_shape := BoxShape3D.new()
    ground_shape.size = Vector3(80, 0.2, 80)
    ground_collision.shape = ground_shape
    ground_collision.position.y = -0.1
    ground.add_child(ground_collision)
    add_child(ground)

    for i in range(12):
        var marker := MeshInstance3D.new()
        var rock := SphereMesh.new()
        rock.radius = 0.8
        rock.height = 1.3
        marker.mesh = rock
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.32, 0.34, 0.3)
        marker.material_override = material
        marker.position = Vector3(float((i % 4) * 8 - 12), 0.6, float(int(i / 4) * 10 - 10))
        add_child(marker)

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
    add_child(camera_pivot)

    var camera := Camera3D.new()
    camera.position = Vector3(0, 3.2, 7.5)
    camera.look_at(Vector3.ZERO, Vector3.UP)
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
