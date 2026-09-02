extends Node2D

const DIE_SCENE := preload("res://scenes/Die.tscn")
const UNIT_TOKEN_SCENE := preload("res://scenes/unit_token.tscn")

@export var spawn_area: Vector2 = Vector2(256, 256)
const SPAWN_SPREAD := 40.0
const CLASH_DICE_COUNT := 3

## Dice were built for a full-size scene - shrink them to fit inside the
## 512x512 dice tray viewport. Tune this until they look right in the felt.
const DICE_SCALE := 0.35

const MARCH_DURATION := 3.0  # seconds for a token to cross the whole track

enum Phase { TYPE, QUANTITY, CLASH }

@export var boss_icon: Texture2D
@export var rare_icons: Array[Texture2D] = []
@export var common_icons: Array[Texture2D] = []

const SUM_TO_RANGE := {
	2: "boss",
	3: "rare", 4: "rare",
	5: "common", 6: "common", 7: "common", 8: "common", 9: "common",
	10: "rare", 11: "rare",
	12: "rare",
}

const ICON_NAMES := ["Heart", "Skull", "Fist", "Sword", "Shield", "Swirl"]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color(1, 1, 1),
	Color(0.4, 0.9, 0.45),
	Color(0.4, 0.6, 1.0),
	Color(0.7, 0.35, 0.9),
	Color(1.0, 0.84, 0.2),
]

@onready var selector: DiceCountSelector = $DiceCountSelector

var phase: Phase = Phase.TYPE
var rolled_values: Array[int] = []
var rolled_rarities: Array[int] = []
var dice_expected := 0

var quantity_by_rarity: Dictionary = {}

var active_dice: Array[Die] = []
var active_result_icons: Array[CanvasItem] = []

var type_dice: Array[Die] = []
var unit_icon: Sprite2D = null

var awaiting_advance := false


func _ready() -> void:
	selector.count_selected.connect(_on_count_selected)
	_enter_phase(Phase.TYPE)


func _enter_phase(new_phase: Phase) -> void:
	_clear_active_dice()
	phase = new_phase
	rolled_values.clear()
	rolled_rarities.clear()

	match phase:
		Phase.TYPE:
			_clear_result_icons()
			_clear_type_dice()
			if unit_icon:
				unit_icon.queue_free()
				unit_icon = null
			selector.visible = false
		Phase.QUANTITY:
			selector.visible = true
		Phase.CLASH:
			selector.visible = false
			_spawn_dice(CLASH_DICE_COUNT, Die.ICON_ROW, true)


func _clear_active_dice() -> void:
	for die in active_dice:
		if is_instance_valid(die):
			die.queue_free()
	active_dice.clear()


func _clear_type_dice() -> void:
	for die in type_dice:
		if is_instance_valid(die):
			die.queue_free()
	type_dice.clear()


func _clear_result_icons() -> void:
	for icon in active_result_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	active_result_icons.clear()


func _input(event: InputEvent) -> void:
	print("input reached DiceRoller: ", event)
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if awaiting_advance:
		awaiting_advance = false
		if phase == Phase.QUANTITY:
			_enter_phase(Phase.CLASH)
		elif phase == Phase.CLASH:
			_enter_phase(Phase.TYPE)
		return

	if phase == Phase.TYPE:
		_spawn_dice(2, Die.NUMBER_ROW, false, true)


func _on_count_selected(count: int) -> void:
	if phase != Phase.QUANTITY:
		return
	_clear_result_icons()
	_spawn_dice(count, Die.NUMBER_ROW, true)


func _spawn_dice(count: int, row: int, use_rarity: bool, track_as_type: bool = false) -> void:
	dice_expected = count
	rolled_values.clear()
	rolled_rarities.clear()
	for i in count:
		var die: Die = DIE_SCENE.instantiate()
		add_child(die)
		die.scale = Vector2(DICE_SCALE, DICE_SCALE)
		if track_as_type:
			type_dice.append(die)
		else:
			active_dice.append(die)
		die.result_locked.connect(_on_die_result_locked)
		var offset := Vector2(randf_range(-SPAWN_SPREAD, SPAWN_SPREAD), randf_range(-SPAWN_SPREAD, SPAWN_SPREAD))
		die.summon(spawn_area + offset, count, row, use_rarity)


func _on_die_result_locked(value: int, rarity: int) -> void:
	rolled_values.append(value)
	rolled_rarities.append(rarity)
	if rolled_values.size() < dice_expected:
		return

	match phase:
		Phase.TYPE:
			var total := 0
			for v in rolled_values:
				total += v
			var range_key: String = SUM_TO_RANGE.get(total, "common")
			var pool: Array[Texture2D] = _pool_for_range(range_key)
			if pool.is_empty():
				_enter_phase(Phase.QUANTITY)
				return
			var chosen_texture: Texture2D = pool[randi() % pool.size()]
			_show_unit_icon(chosen_texture)
			_spawn_marching_token(chosen_texture)
			_enter_phase(Phase.QUANTITY)

		Phase.QUANTITY:
			quantity_by_rarity.clear()
			for i in rolled_values.size():
				var r: int = rolled_rarities[i]
				var v: int = rolled_values[i]
				quantity_by_rarity[r] = quantity_by_rarity.get(r, 0) + v
			_show_quantity_results()
			selector.visible = false
			awaiting_advance = true

		Phase.CLASH:
			_show_clash_results()
			awaiting_advance = true


func _pool_for_range(range_key: String) -> Array[Texture2D]:
	match range_key:
		"boss":
			var boss_pool: Array[Texture2D] = []
			if boss_icon:
				boss_pool.append(boss_icon)
			return boss_pool
		"rare":
			return rare_icons
		_:
			return common_icons


func _show_unit_icon(texture: Texture2D) -> void:
	if unit_icon:
		unit_icon.queue_free()
	unit_icon = Sprite2D.new()
	unit_icon.texture = texture
	unit_icon.position = spawn_area + Vector2(0, -140)
	add_child(unit_icon)


## NEW: this is the piece that was never wired up - spawns a UnitToken
## on the march track (which lives in a totally different scene/viewport,
## found via group membership) and tweens it across over MARCH_DURATION.
func _spawn_marching_token(texture: Texture2D) -> void:
	var track: Path2D = get_tree().get_first_node_in_group("march_track")
	if track == null:
		push_warning("No node in group 'march_track' - did you add MarchTrack to it?")
		return
	var follow := PathFollow2D.new()
	follow.rotates = false
	track.add_child(follow)

	var token: UnitToken = UNIT_TOKEN_SCENE.instantiate()
	follow.add_child(token)
	token.set_icon_texture(texture)

	var tween := create_tween()
	tween.tween_property(follow, "progress_ratio", 1.0, MARCH_DURATION)
	tween.finished.connect(func(): follow.queue_free())


func _show_quantity_results() -> void:
	var index := 0
	for r in quantity_by_rarity.keys():
		var count: int = quantity_by_rarity[r]
		var icon := Sprite2D.new()
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(RARITY_COLORS[r])
		icon.texture = ImageTexture.create_from_image(img)
		icon.position = spawn_area + Vector2(-100 + index * 70, -60)
		add_child(icon)
		active_result_icons.append(icon)

		var label := Label.new()
		label.text = str(count)
		label.position = icon.position + Vector2(-8, 20)
		add_child(label)
		active_result_icons.append(label)
		index += 1


func _show_clash_results() -> void:
	var index := 0
	for i in rolled_values.size():
		var icon_name: String = ICON_NAMES[rolled_values[i] - 1]
		var rarity: int = rolled_rarities[i]
		var label := Label.new()
		label.text = icon_name
		label.modulate = RARITY_COLORS[rarity]
		label.position = spawn_area + Vector2(-60 + index * 60, -60)
		add_child(label)
		active_result_icons.append(label)
		index += 1


func trigger_roll() -> void:
	if awaiting_advance:
		awaiting_advance = false
		if phase == Phase.QUANTITY:
			_enter_phase(Phase.CLASH)
		elif phase == Phase.CLASH:
			_enter_phase(Phase.TYPE)
		return

	if phase == Phase.TYPE:
		_spawn_dice(2, Die.NUMBER_ROW, false, true)
