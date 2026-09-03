extends Node2D

const DIE_SCENE := preload("res://scenes/Die.tscn")
const UNIT_TOKEN_SCENE := preload("res://scenes/unit_token.tscn")

## Center of the felt bowl inside the 188x188 DiceRollerViewport (see
## battle_ui.tscn's DiceRollerContainer - it's sized/positioned to match
## the actual green circle in ui/DiceTray.png, not a round number).
@export var spawn_area: Vector2 = Vector2(94, 94)

## Radius of that same green felt circle, in the same viewport-local
## pixels as spawn_area. Everything that renders inside the tray (dice,
## walls, the roll-result label, the clash-result labels) sizes and
## positions itself relative to this so nothing can render past the felt
## and onto the wood border - see _build_tray_walls(), _show_roll_result()
## and _show_clash_results() below.
const FELT_RADIUS := 84.0

const SPAWN_SPREAD := 8.0
const CLASH_DICE_COUNT := 3

## The QUANTITY phase used to let the player drag-pick a dice count via a
## DiceCountSelector living inside the tray. That selector never fit the
## tray well and is being redesigned separately (see DiceCountSelector.gd) -
## for now QUANTITY just auto-rolls a fixed number of dice immediately
## after a unit is drafted, so a single roll takes you straight from
## "click the felt" to "units marching down the path".
const QUANTITY_DICE_COUNT := 3

## Dice were built for a full-size scene - shrink them to fit inside the
## small felt-bowl viewport no matter how many are thrown at once (1-6).
## Scale shrinks as count grows instead of using one fixed size, so a
## single die and a full six-dice throw both stay inside the circle.
const DICE_SCALE_BASE := 0.28
const DICE_SCALE_MIN := 0.08

const MARCH_DURATION := 3.0  # seconds for a token to cross the whole track
const MAX_UNITS_PER_DRAFT := 8  # keeps a single draft's march readable; tune freely

## Seconds between each drafted unit's march start. UnitToken's icon renders
## at ~0.4x a 256px source avatar (~100px wide - see unit_token.gd's
## icon_scale), and the track covers ~445px in MARCH_DURATION seconds, so a
## short stagger has consecutive tokens overlapping several deep instead of
## reading as a line of units. This spacing keeps a full gap between them.
const MARCH_STAGGER := 0.8

const WAVE_COUNT := 5
const MAX_VILLAGE_HP := 20

## First-draft CLASH resolution rules. CLASH is cut from the active phase
## loop for now (see the Phase enum below) to get the core roll -> unit ->
## march loop working first; this and the functions below it
## (_resolve_clash, _show_clash_results, _roll_defender_rarity, _end_run)
## are dead code until CLASH is reworked and wired back in. Left in place
## rather than deleted since the concept doc marks the exact clash format
## as still undecided anyway - treat these numbers as placeholders.
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

## CLASH is never entered right now - _input()/trigger_roll() send
## QUANTITY straight back to TYPE. Kept in the enum (rather than removed)
## because _enter_phase() and _on_die_result_locked() still have a
## Phase.CLASH case ready for when the mechanic gets reworked.
enum Phase { TYPE, QUANTITY, CLASH }

@export var boss_icon: Texture2D
@export var rare_icons: Array[Texture2D] = []
@export var common_icons: Array[Texture2D] = []

## Display names for the roll ledger (see get_ledger_rows() below), index
## for index against boss_icon/rare_icons/common_icons. Left empty by
## default rather than hardcoded here - fill these in from the Inspector
## to name the ledger's units without touching code, per the design doc's
## "player wants choice over which units populate the ledger" note. Any
## icon without a matching name falls back to a numbered placeholder.
@export var boss_name: String = "Boss"
@export var rare_names: Array[String] = []
@export var common_names: Array[String] = []

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

var phase: Phase = Phase.TYPE
var rolled_values: Array[int] = []
var rolled_rarities: Array[int] = []
var dice_expected := 0

var quantity_by_rarity: Dictionary = {}

var active_dice: Array[Die] = []
var active_result_icons: Array[CanvasItem] = []

var type_dice: Array[Die] = []
var roll_result_label: Label = null
var drafted_texture: Texture2D = null

var awaiting_advance := false

## True from the moment a TYPE roll is triggered until QUANTITY's dice lock
## and awaiting_advance goes true - i.e. exactly the window where dice are
## actually tumbling and no new roll should be startable. Without this,
## clicking the felt again while TYPE (or QUANTITY) dice were still rolling
## called _spawn_dice() again on top of the still-active ones - dice_expected/
## rolled_values got reset out from under the in-flight roll, and the tray
## filled up with orphaned extra dice from every extra click.
var rolling := false

var wave := 1
var village_hp := MAX_VILLAGE_HP
var run_over := false

## Which portal the next draft marches out of - "left" or "right". Set by
## the player clicking a path in battle_ui.gd (PathLeftButton/PathRightButton).
var march_side := "left"


func set_march_side(side: String) -> void:
	march_side = side


func _ready() -> void:
	_build_tray_walls()
	_enter_phase(Phase.TYPE)


## The tray is small and dice fling at up to FLING_MAX px/s in Die.gd,
## easily enough to sail past the felt's edge before damping pulls them
## back. Box the roll area in with invisible walls so flung dice bounce
## back into view instead of settling somewhere outside the tray.
##
## The box is a square *inscribed inside* the felt circle (half-extent =
## radius / sqrt(2)) rather than one sized to the circle's bounding box -
## a bounding-box wall lets dice settle in its corners, which sit outside
## the round felt and on top of the wood border.
func _build_tray_walls() -> void:
	var half_extent := FELT_RADIUS / sqrt(2.0)
	var half_extents := Vector2(half_extent, half_extent)
	var thickness := 14.0
	_add_wall(spawn_area + Vector2(0, -half_extents.y), Vector2(half_extents.x * 2, thickness))
	_add_wall(spawn_area + Vector2(0, half_extents.y), Vector2(half_extents.x * 2, thickness))
	_add_wall(spawn_area + Vector2(-half_extents.x, 0), Vector2(thickness, half_extents.y * 2))
	_add_wall(spawn_area + Vector2(half_extents.x, 0), Vector2(thickness, half_extents.y * 2))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)


func _enter_phase(new_phase: Phase) -> void:
	_clear_active_dice()
	phase = new_phase
	rolled_values.clear()
	rolled_rarities.clear()

	match phase:
		Phase.TYPE:
			_clear_result_icons()
			_clear_type_dice()
			if roll_result_label:
				roll_result_label.queue_free()
				roll_result_label = null
		Phase.QUANTITY:
			_spawn_dice(QUANTITY_DICE_COUNT, Die.NUMBER_ROW, true)
		Phase.CLASH:
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
			_enter_phase(Phase.TYPE)
		return

	if phase == Phase.TYPE and not rolling:
		rolling = true
		_spawn_dice(2, Die.NUMBER_ROW, false, true)


func _spawn_dice(count: int, row: int, use_rarity: bool, track_as_type: bool = false) -> void:
	dice_expected = count
	rolled_values.clear()
	rolled_rarities.clear()
	var die_scale := _dice_scale_for_count(count)
	for i in count:
		var die: Die = DIE_SCENE.instantiate()
		add_child(die)
		# Not die.scale = ... - see Die.set_visual_scale()'s comment for why
		# scaling a RigidBody2D directly doesn't stick.
		die.set_visual_scale(die_scale)
		if track_as_type:
			type_dice.append(die)
		else:
			active_dice.append(die)
		die.result_locked.connect(_on_die_result_locked)
		var offset := Vector2(randf_range(-SPAWN_SPREAD, SPAWN_SPREAD), randf_range(-SPAWN_SPREAD, SPAWN_SPREAD))
		die.summon(spawn_area + offset, count, row, use_rarity)


## More dice thrown at once = smaller scale, so 1 die and 6 dice both fit
## inside the felt circle instead of one fixed size working for neither.
func _dice_scale_for_count(count: int) -> float:
	return clampf(DICE_SCALE_BASE / sqrt(float(count)), DICE_SCALE_MIN, DICE_SCALE_BASE)


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
			_show_roll_result(total)
			_enter_phase(Phase.QUANTITY)

		Phase.QUANTITY:
			quantity_by_rarity.clear()
			for i in rolled_values.size():
				var r: int = rolled_rarities[i]
				var v: int = rolled_values[i]
				quantity_by_rarity[r] = quantity_by_rarity.get(r, 0) + v
			_spawn_drafted_units()
			awaiting_advance = true
			rolling = false

		Phase.CLASH:
			_show_clash_results()
			_resolve_clash()
			if not run_over:
				awaiting_advance = true
				rolling = false


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


## Player-facing summary of which TYPE-roll (2d6 sum) ranges currently
## draft which units - the "roll ledger" from the design doc. Rebuilt on
## demand (see battle_ui.gd's ledger button) rather than cached, so it
## always reflects whatever's actually in the pools right now instead of
## going stale if the pools change mid-run.
func get_ledger_rows() -> Array[String]:
	var rows: Array[String] = []
	var range_start := 2
	var current_key: String = SUM_TO_RANGE.get(2, "common")
	for sum in range(3, 13):
		var key: String = SUM_TO_RANGE.get(sum, "common")
		if key != current_key:
			rows.append(_format_ledger_row(range_start, sum - 1, current_key))
			range_start = sum
			current_key = key
	rows.append(_format_ledger_row(range_start, 12, current_key))
	return rows


func _format_ledger_row(low: int, high: int, range_key: String) -> String:
	var sum_label := "%d" % low if low == high else "%d-%d" % [low, high]
	var names := _names_for_range(range_key)
	var names_text := ", ".join(names) if not names.is_empty() else "(none set)"
	return "%s (%s): %s" % [sum_label, range_key.capitalize(), names_text]


func _names_for_range(range_key: String) -> Array[String]:
	match range_key:
		"boss":
			# Not `[boss_name] if boss_icon else []` - a bare array literal
			# like that is an untyped Array even though the ternary sits in
			# an Array[String]-returning function, and assigning it at the
			# call site throws at runtime ("Trying to assign an array of
			# type Array to a variable of type Array[String]").
			var boss_names: Array[String] = []
			if boss_icon:
				boss_names.append(boss_name)
			return boss_names
		"rare":
			return rare_names if rare_names.size() == rare_icons.size() else _placeholder_names(rare_icons.size())
		_:
			return common_names if common_names.size() == common_icons.size() else _placeholder_names(common_icons.size())


func _placeholder_names(count: int) -> Array[String]:
	var names: Array[String] = []
	for i in count:
		names.append("Unit %d" % (i + 1))
	return names


const ROLL_RESULT_LABEL_SIZE := Vector2(56, 36)

## Shows the TYPE roll's 2d6 total as plain text near the top of the felt,
## above where the QUANTITY dice land, instead of the old unit-avatar icon
## (which sat right in the middle of the tray, overlapping the dice while
## they rolled). Check the Roll Ledger for what a given total actually
## drafts - see get_ledger_rows().
func _show_roll_result(total: int) -> void:
	if roll_result_label:
		roll_result_label.queue_free()
	roll_result_label = Label.new()
	roll_result_label.text = str(total)
	roll_result_label.add_theme_font_size_override("font_size", 28)
	roll_result_label.size = ROLL_RESULT_LABEL_SIZE
	roll_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var center := spawn_area + Vector2(0, -55)
	roll_result_label.position = center - ROLL_RESULT_LABEL_SIZE / 2.0
	add_child(roll_result_label)


## Sends every unit drafted this QUANTITY roll marching down the track,
## one by one, tinted by whichever rarity die produced it. Total is capped
## at MAX_UNITS_PER_DRAFT so a lucky legendary-heavy roll doesn't flood the
## track with dozens of overlapping tokens. Rarest first: quantity_by_rarity
## is keyed by whichever die happened to physically settle first, which has
## nothing to do with rarity - iterating it in insertion order let an early
## common/uncommon die's count fill the whole cap before a later rare/epic/
## legendary die's count ever got a turn, silently discarding it. Spawning
## highest rarity first means a rarer die's units are never dropped in
## favor of a lesser one.
func _spawn_drafted_units() -> void:
	if drafted_texture == null:
		return
	var spawned := 0
	for rarity in range(Die.Rarity.LEGENDARY, Die.Rarity.COMMON - 1, -1):
		if not quantity_by_rarity.has(rarity):
			continue
		var count: int = quantity_by_rarity[rarity]
		for i in count:
			if spawned >= MAX_UNITS_PER_DRAFT:
				return
			_spawn_marching_token(drafted_texture, rarity, spawned * MARCH_STAGGER)
			spawned += 1


## Spawns a UnitToken on the march track (which lives in a totally
## different scene/viewport - see march_track_left/right below for how we
## reach it) and tweens it across over MARCH_DURATION, then hands it off to
## _on_march_finished.
func _spawn_marching_token(texture: Texture2D, rarity: int, start_delay: float = 0.0) -> void:
	var track := _get_march_track()
	if track == null:
		push_warning("march_track_left/march_track_right are both unset - did battle_ui.gd's _ready() wire them up?")
		return
	var follow := PathFollow2D.new()
	follow.rotates = false
	# add_child() MUST come before touching progress_ratio - PathFollow2D
	# needs its parent Path2D to already be in the tree to resolve a curve
	# position at all, and setting the property on a freshly-.new()'d node
	# (no parent yet) throws "Can only set progress ratio on a PathFollow2D
	# that is the child of a Path2D which is itself part of the scene
	# tree." This was always wrong, just never reached before track lookup
	# was fixed - _get_march_track() used to return null and bail out here
	# first every time.
	track.add_child(follow)
	follow.progress_ratio = 0.0

	var token: UnitToken = UNIT_TOKEN_SCENE.instantiate()
	follow.add_child(token)
	token.set_icon_texture(texture)
	token.set_facing_left(march_side == "left")
	token.modulate = RARITY_COLORS[rarity]

	var tween := create_tween()
	tween.tween_interval(start_delay)
	tween.tween_property(follow, "progress_ratio", 1.0, MARCH_DURATION)
	tween.finished.connect(_on_march_finished.bind(follow))


## Handed to us directly by battle_ui.gd's _ready() rather than discovered
## via get_tree().get_nodes_in_group("march_track") - a node's
## `groups=PackedStringArray(...)` .tscn property was verified (against a
## minimal throwaway scene, so it's not specific to these two nodes) to not
## register at all under the Godot build this was checked against, so group
## lookup can't be relied on for this.
var march_track_left: Path2D = null
var march_track_right: Path2D = null


func _get_march_track() -> Path2D:
	var target := march_track_left if march_side == "left" else march_track_right
	return target if target != null else (march_track_right if march_track_left == null else march_track_left)


## A token reached the end of the screen-space march track and vanishes.
##
## TODO(portal): this is where the actual siege should begin - a portal
## effect opening in the village (found via the "battle_world" group,
## already tagged on village.tscn) that the real unit walks out of and
## starts attacking from. Deliberately not built yet - for now the token
## just disappears at the track's end.
func _on_march_finished(follow: PathFollow2D) -> void:
	follow.queue_free()


## CLASH_DICE_COUNT labels laid out side by side. Each is sized and
## center-anchored (rather than positioned by its top-left corner) so the
## row can be placed by its centers and kept within FELT_RADIUS - the
## previous fixed corner offsets pushed the outer labels well past the
## felt and onto the wood tray.
const CLASH_LABEL_SIZE := Vector2(70, 20)
const CLASH_LABEL_SPACING := 40.0

func _show_clash_results() -> void:
	var index := 0
	for i in rolled_values.size():
		var icon_name: String = ICON_NAMES[rolled_values[i] - 1]
		var rarity: int = rolled_rarities[i]
		var label := Label.new()
		label.text = icon_name
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = RARITY_COLORS[rarity]
		label.size = CLASH_LABEL_SIZE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var offset_from_middle := (index - (rolled_values.size() - 1) / 2.0) * CLASH_LABEL_SPACING
		var center := spawn_area + Vector2(offset_from_middle, -8)
		label.position = center - CLASH_LABEL_SIZE / 2.0
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
			_enter_phase(Phase.TYPE)
		return

	if phase == Phase.TYPE and not rolling:
		rolling = true
		_spawn_dice(2, Die.NUMBER_ROW, false, true)
