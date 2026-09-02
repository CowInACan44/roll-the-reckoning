@tool
extends Node2D
class_name UnitToken
## Stick + icon combo that rides the march track. Marked @tool so the
## exported values below update live in the editor viewport as you drag
## them in the Inspector - no need to hit Play to see sizing changes.

@onready var stick: Sprite2D = $Stick
@onready var icon: Sprite2D = $Icon

const BOB_SPEED := 6.0
const BOB_AMOUNT := 6.0  # degrees of left-right tilt while marching

## Drag these three in the Inspector and watch the token update live.
@export_range(0.01, 1.0, 0.01) var stick_scale: float = 0.08:
	set(value):
		stick_scale = value
		_apply_stick_scale()

@export_range(0.01, 1.0, 0.01) var icon_scale: float = 0.4:
	set(value):
		icon_scale = value
		_apply_icon_scale()

## Positive = stick moves down, so you can plant its base on the track
## line instead of it floating centered on the path.
@export_range(-100.0, 100.0, 1.0) var stick_vertical_offset: float = 0.0:
	set(value):
		stick_vertical_offset = value
		_apply_stick_offset()

var _bob_time := 0.0


func _ready() -> void:
	_apply_stick_scale()
	_apply_icon_scale()
	_apply_stick_offset()


func _apply_stick_scale() -> void:
	if stick:
		stick.scale = Vector2(stick_scale, stick_scale)


func _apply_icon_scale() -> void:
	if icon:
		icon.scale = Vector2(icon_scale, icon_scale)


func _apply_stick_offset() -> void:
	if stick:
		stick.position.y = stick_vertical_offset


## Call this once when a unit is drafted, to hand this token its icon art.
func set_icon_texture(texture: Texture2D) -> void:
	if icon:
		icon.texture = texture


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return  # don't bob while editing in the viewport, only at runtime
	_bob_time += delta
	rotation_degrees = sin(_bob_time * BOB_SPEED) * BOB_AMOUNT
