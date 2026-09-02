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
const MAX_UNITS_PER_DRAFT := 8  # keeps a single draft's march readable; tune freely

const WAVE_COUNT := 5
const MAX_VILLAGE_HP := 20

## First-draft CLASH resolution rules. The concept doc marks the exact
## clash format as still undecided - treat these numbers as placeholders
## to rebalance once the real rules are nailed down, not a final design.
const CLASH_SIEGE_DAMAGE := {
	# icon index (matches ICON_NAMES) -> village HP lost if the summoned
	# monsters win that lane's rarity contest against the defenders
	0: 1, # Heart
	1: 3, # Skull
	2: 2, # Fist
	3: 2, # Sword
	4: 1, # Shield
	5: 2, # Swirl
}
const DEFENDER_WIN_HEAL := 1  # village HP recovered per lane the defenders win

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
var drafted_texture: Texture2D = null

var awaiting_advance := false

var wave := 1
var village_hp := MAX_VILLAGE_HP
var run_over := false
var world_units: Array[Node2D] = []


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
			selector.max_count = clampi(wave + 1, 1, 6)
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
	if run_over:
		return
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
			drafted_texture = pool[randi() % pool.size()]
			_show_unit_icon(drafted_texture)
			_enter_phase(Phase.QUANTITY)

		Phase.QUANTITY:
			quantity_by_rarity.clear()
			for i in rolled_values.size():
				var r: int = rolled_rarities[i]
				var v: int = rolled_values[i]
				quantity_by_rarity[r] = quantity_by_rarity.get(r, 0) + v
			_show_quantity_results()
			_spawn_drafted_units()
			selector.visible = false
			awaiting_advance = true

		Phase.CLASH:
			_show_clash_results()
			_resolve_clash()
			if not run_over:
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


## Sends every unit drafted this QUANTITY roll marching down the track,
## one by one, tinted by whichever rarity die produced it. Total is capped
## at MAX_UNITS_PER_DRAFT so a lucky legendary-heavy roll doesn't flood the
## track with dozens of overlapping tokens.
func _spawn_drafted_units() -> void:
	if drafted_texture == null:
		return
	var spawned := 0
	for rarity in quantity_by_rarity.keys():
		var count: int = quantity_by_rarity[rarity]
		for i in count:
			if spawned >= MAX_UNITS_PER_DRAFT:
				return
			_spawn_marching_token(drafted_texture, rarity, spawned * 0.15)
			spawned += 1


## Spawns a UnitToken on the march track (which lives in a totally
## different scene/viewport, found via group membership) and tweens it
## across over MARCH_DURATION, then hands it off to _on_march_finished.
func _spawn_marching_token(texture: Texture2D, rarity: int, start_delay: float = 0.0) -> void:
	var track: Path2D = get_tree().get_first_node_in_group("march_track")
	if track == null:
		push_warning("No node in group 'march_track' - did you add MarchTrack to it?")
		return
	var follow := PathFollow2D.new()
	follow.rotates = false
	follow.progress_ratio = 0.0
	track.add_child(follow)

	var token: UnitToken = UNIT_TOKEN_SCENE.instantiate()
	follow.add_child(token)
	token.set_icon_texture(texture)
	token.modulate = RARITY_COLORS[rarity]

	var tween := create_tween()
	tween.tween_interval(start_delay)
	tween.tween_property(follow, "progress_ratio", 1.0, MARCH_DURATION)
	tween.finished.connect(_on_march_finished.bind(follow, token))


## A token reached the end of the screen-space march track. Hand it off to
## whatever's in the "battle_world" group so it becomes a real unit
## standing in the village instead of just despawning at the screen edge.
##
## NOTE: this assumes no Camera2D exists yet, so the UI canvas layer and
## the world canvas currently line up 1:1 in pixel space. Once the planned
## RTS pan/zoom camera goes in, this needs a real screen-to-world
## conversion instead of a straight reparent.
func _on_march_finished(follow: PathFollow2D, token: UnitToken) -> void:
	if run_over:
		follow.queue_free()
		return
	var world: Node2D = get_tree().get_first_node_in_group("battle_world")
	if world == null:
		push_warning("No node in group 'battle_world' - did you add it to the village scene?")
		follow.queue_free()
		return
	var landing_spot := follow.global_position + Vector2(randf_range(-24, 24), randf_range(-12, 12))
	token.reparent(world, true)
	token.global_position = landing_spot
	follow.queue_free()
	world_units.append(token)


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


## Resolves this wave's CLASH exchange: each of the 3 rolled icon lanes
## pits the summoned monsters' rarity against an instantly-rolled defender
## rarity (the village's counter-roll - it doesn't get physical dice, just
## a weighted pick using the same table Die.gd uses). The winning side
## applies that icon's effect from CLASH_SIEGE_DAMAGE above.
func _resolve_clash() -> void:
	for i in rolled_values.size():
		var icon_index: int = rolled_values[i] - 1
		var monster_rarity: int = rolled_rarities[i]
		var defender_rarity: int = _roll_defender_rarity()
		if monster_rarity > defender_rarity:
			village_hp -= CLASH_SIEGE_DAMAGE.get(icon_index, 1)
		elif defender_rarity > monster_rarity:
			village_hp = mini(village_hp + DEFENDER_WIN_HEAL, MAX_VILLAGE_HP)
			_lose_one_unit()
	village_hp = clampi(village_hp, 0, MAX_VILLAGE_HP)
	_update_hud()

	if village_hp <= 0:
		_end_run(true)
		return

	wave += 1
	if wave > WAVE_COUNT:
		_end_run(false)


func _roll_defender_rarity() -> int:
	var total := 0.0
	for w in Die.RARITY_WEIGHTS.values():
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for rarity in Die.RARITY_WEIGHTS.keys():
		cumulative += Die.RARITY_WEIGHTS[rarity]
		if roll <= cumulative:
			return rarity
	return Die.Rarity.COMMON


func _lose_one_unit() -> void:
	if world_units.is_empty():
		return
	var unit: Node2D = world_units.pop_back()
	if is_instance_valid(unit):
		unit.queue_free()


func _end_run(village_fell: bool) -> void:
	run_over = true
	var hud := _get_hud()
	if hud == null:
		return
	var banner: Label = hud.get_node_or_null("ResultBanner")
	if banner:
		banner.text = "VICTORY - the village has fallen!" if village_fell else "DEFEAT - the village held out all %d waves." % WAVE_COUNT


func _get_hud() -> Control:
	return get_tree().get_first_node_in_group("battle_hud") as Control


func _update_hud() -> void:
	var hud := _get_hud()
	if hud == null:
		return
	var wave_label: Label = hud.get_node_or_null("WaveLabel")
	if wave_label:
		wave_label.text = "Wave %d/%d" % [mini(wave, WAVE_COUNT), WAVE_COUNT]
	var hp_label: Label = hud.get_node_or_null("VillageHPLabel")
	if hp_label:
		hp_label.text = "Village HP: %d/%d" % [village_hp, MAX_VILLAGE_HP]


func trigger_roll() -> void:
	if run_over:
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
