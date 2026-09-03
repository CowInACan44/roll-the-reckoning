extends RigidBody2D
class_name Die

## Now emits (value, rarity) instead of just value. `rarity` is always
## Rarity.COMMON unless this roll opted into rarity tinting.
signal result_locked(value: int, rarity: int)

## UpscaledDice_White.png grid: 112x112 cells.
const CELL_SIZE := Vector2(112, 112)
const NUMBER_ROW := 1
const ICON_ROW := 3  # heart, skull, fist, sword, shield, swirl

const ROLL_TICK := 0.07
const MIN_ROLL_TIME := 0.3
const SETTLE_LINEAR := 10.0
const SETTLE_ANGULAR := 0.5
const FLING_MIN := 150.0
const FLING_MAX := 320.0
const SPIN_MAX := 10.0

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_WEIGHTS := {
	Rarity.COMMON: 60.0,
	Rarity.UNCOMMON: 25.0,
	Rarity.RARE: 10.0,
	Rarity.EPIC: 4.0,
	Rarity.LEGENDARY: 1.0,
}

const RARITY_COLORS := {
	Rarity.COMMON: Color(1, 1, 1),
	Rarity.UNCOMMON: Color(0.4, 0.9, 0.45),
	Rarity.RARE: Color(0.4, 0.6, 1.0),
	Rarity.EPIC: Color(0.7, 0.35, 0.9),
	Rarity.LEGENDARY: Color(1.0, 0.84, 0.2),
}

var is_rolling := false
var current_value := 1
var current_rarity: Rarity = Rarity.COMMON
var result_row := NUMBER_ROW
var rarity_enabled := false
var _roll_elapsed := 0.0

@onready var tumble: AnimatedSprite2D = $AnimatedSprite2D
@onready var numeral: Sprite2D = $NumeralSprite
@onready var roll_timer: Timer = $RollTimer
@onready var roll_sound: AudioStreamPlayer = $RollSound
@onready var collision: CollisionShape2D = $CollisionShape2D

var roll_sounds: Array[AudioStream] = [
	preload("res://dice/d6/Roll 1d6.wav"),
	preload("res://dice/d6/Roll 2d6.wav"),
	preload("res://dice/d6/Roll 3d6.wav"),
	preload("res://dice/d6/Roll 4d6.wav"),
	preload("res://dice/d6/Roll 5d6.wav"),
	preload("res://dice/d6/Roll 6d6.wav"),
]


func _ready() -> void:
	numeral.region_enabled = true
	numeral.visible = false
	tumble.visible = false

	gravity_scale = 0.0
	linear_damp = 4.0
	angular_damp = 6.0

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.4
	mat.friction = 0.3
	physics_material_override = mat

	roll_timer.wait_time = ROLL_TICK
	roll_timer.timeout.connect(_on_roll_timer_timeout)


## Sets how big this die renders and collides. Scales tumble/numeral/collision
## individually rather than the Die (RigidBody2D) node's own `scale` -
## RigidBody2D re-derives its global transform from the physics server every
## physics step, and the physics server has no concept of Node2D scale, so a
## scale set on the body itself gets silently reset to 1.0 on the next
## physics tick no matter when it's set. Scaling the (non-physics) children
## instead sticks, and still correctly shrinks the actual collision shape.
func set_visual_scale(s: float) -> void:
	tumble.scale = Vector2(s, s)
	numeral.scale = Vector2(s, s)
	collision.scale = Vector2(s, s)


func summon(at_position: Vector2, dice_count: int = 1, row: int = NUMBER_ROW, use_rarity: bool = false) -> void:
	if is_rolling:
		return

	global_position = at_position
	rotation = 0.0
	result_row = row
	rarity_enabled = use_rarity
	is_rolling = true
	_roll_elapsed = 0.0

	current_rarity = _pick_rarity() if use_rarity else Rarity.COMMON
	var tint: Color = RARITY_COLORS[current_rarity]
	tumble.modulate = tint
	numeral.modulate = tint

	numeral.visible = false
	tumble.visible = true
	tumble.play("default")
	roll_timer.start()
	_play_roll_sound(dice_count)

	var fling_dir := Vector2.RIGHT.rotated(randf_range(0, TAU))
	linear_velocity = fling_dir * randf_range(FLING_MIN, FLING_MAX)
	angular_velocity = randf_range(-SPIN_MAX, SPIN_MAX)


func _pick_rarity() -> Rarity:
	var total := 0.0
	for w in RARITY_WEIGHTS.values():
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for rarity in RARITY_WEIGHTS.keys():
		cumulative += RARITY_WEIGHTS[rarity]
		if roll <= cumulative:
			return rarity
	return Rarity.COMMON


func _physics_process(delta: float) -> void:
	if not is_rolling:
		return
	_roll_elapsed += delta
	if _roll_elapsed < MIN_ROLL_TIME:
		return
	if linear_velocity.length() < SETTLE_LINEAR and abs(angular_velocity) < SETTLE_ANGULAR:
		_lock_result()


func _on_roll_timer_timeout() -> void:
	current_value = randi_range(1, 6)


func _play_roll_sound(dice_count: int) -> void:
	if roll_sounds.is_empty():
		return
	var index := clampi(dice_count - 1, 0, roll_sounds.size() - 1)
	roll_sound.stream = roll_sounds[index]
	roll_sound.play()


func _lock_result() -> void:
	is_rolling = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	roll_timer.stop()
	tumble.stop()
	tumble.visible = false
	numeral.region_rect = Rect2(Vector2(current_value - 1, result_row) * CELL_SIZE, CELL_SIZE)
	numeral.visible = true
	result_locked.emit(current_value, current_rarity)
