extends Node2D
class_name DiceCountSelector

## A row of 6 pip-face icons (from UpscaledDice_White.png row 0, 112x112
## cells). Drag across them to preview a count, release to confirm.
## No text anywhere - the player sees which icons light up and picks by feel.
##
## Sized to fit inside the dice tray's felt circle (see main.gd's
## FELT_RADIUS) - the whole 6-icon row must be narrower than the felt's
## diameter, with room either side for the drag-hover margin below.

signal count_selected(count: int)

const CELL_SIZE := Vector2(112, 112)
const PIP_ROW := 0
const ICON_SCALE := Vector2(0.16, 0.16)
const ICON_SPACING := 22.0

const DIM_COLOR := Color(0.35, 0.35, 0.35, 0.6)
const LIT_COLOR := Color(1, 1, 1, 1)
const LOCK_COLOR := Color(0.15, 0.1, 0.1, 0.5)

var icons: Array[Sprite2D] = []
var is_dragging := false
var hovered_count := 0

@export var dice_sheet: Texture2D

## How many of the 6 icons are actually pickable right now - the rest show
## locked/dim. main.gd raises this as the wave count climbs, so higher
## dice counts (and their bigger rarity swings) unlock later in a run.
var max_count := 6:
	set(value):
		max_count = clampi(value, 1, 6)
		_refresh_icons()


func _ready() -> void:
	for i in 6:
		var icon := Sprite2D.new()
		icon.texture = dice_sheet
		icon.region_enabled = true
		icon.region_rect = Rect2(Vector2(i, PIP_ROW) * CELL_SIZE, CELL_SIZE)
		icon.scale = ICON_SCALE
		icon.position = Vector2(i * ICON_SPACING, 0)
		icon.modulate = DIM_COLOR
		add_child(icon)
		icons.append(icon)
	_refresh_icons()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			_update_hover(event.position)
		else:
			if is_dragging and hovered_count > 0:
				count_selected.emit(hovered_count)
			is_dragging = false
			_reset_highlight()
	elif event is InputEventMouseMotion and is_dragging:
		_update_hover(event.position)


func _update_hover(global_mouse_pos: Vector2) -> void:
	var local_x := to_local(global_mouse_pos).x
	var count := int(round(local_x / ICON_SPACING)) + 1
	count = clampi(count, 1, max_count)

	# Only register as "over the selector" if reasonably close to the row.
	var local_y := to_local(global_mouse_pos).y
	if abs(local_y) > 16:
		_reset_highlight()
		hovered_count = 0
		return

	hovered_count = count
	for i in icons.size():
		icons[i].modulate = LIT_COLOR if i < count else (DIM_COLOR if i < max_count else LOCK_COLOR)


func _reset_highlight() -> void:
	_refresh_icons()


func _refresh_icons() -> void:
	for i in icons.size():
		icons[i].modulate = DIM_COLOR if i < max_count else LOCK_COLOR
