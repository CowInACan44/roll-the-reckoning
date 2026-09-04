extends Camera2D
## Lets the player drag to scroll around the village while planning a siege
## (see LedgerUI/village.gd). Disabled once the siege starts - the camera
## snaps back to its fixed battle framing instead.

var panning_enabled := true

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_cam := Vector2.ZERO
var _home_position: Vector2
var _home_zoom: Vector2


func _ready() -> void:
	_home_position = position
	_home_zoom = zoom


func _unhandled_input(event: InputEvent) -> void:
	if not panning_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start_mouse = event.position
			_drag_start_cam = position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position = _drag_start_cam - (event.position - _drag_start_mouse) / zoom.x


## Called once the siege starts - locks panning back to the original
## battle-framing shot so the fight reads the same as before this mechanic.
func reset_to_battle_view() -> void:
	panning_enabled = false
	_dragging = false
	position = _home_position
	zoom = _home_zoom
