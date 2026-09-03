extends Node
## Autoload singleton ("Ledger"). Owns the ledger mechanic: the full roster
## of units the village could ever field, which of them are unlocked so
## far, and which up-to-MAX_SLOTS are slotted in to be rolled for on the
## run about to start.
##
## A unit's tier ("boss"/"rare"/"common") is which TYPE-phase dice-sum
## bucket draws it - see SUM_TO_RANGE below, which main.gd reads directly
## so the roll table and the ledger's displayed costs can never drift apart.

signal selection_changed

const MAX_SLOTS := 5

## Same 11 avatars main.gd used to hold directly (see the old boss_icon/
## rare_icons/common_icons exports) - centralized here so both the pre-run
## ledger screen and the roller draw from one roster.
const AVATAR_DIR := "res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/"

## Which dice-sum (from the two TYPE-phase dice) draws from which tier.
const SUM_TO_RANGE := {
	2: "boss",
	3: "rare", 4: "rare",
	5: "common", 6: "common", 7: "common", 8: "common", 9: "common",
	10: "rare", 11: "rare", 12: "rare",
}

const TIER_ROLL_HINTS := {
	"boss": "Roll a 2",
	"rare": "Roll 3, 4, 10, 11 or 12",
	"common": "Roll 5-9",
}

## How many of `roster` (in array order - commons, then rares, then the
## boss) the player starts with unlocked. Everything past this index shows
## locked in the ledger. There's no unlock/progression system yet, so this
## is just the starting point future updates can raise.
const STARTING_UNLOCKED := 3


class UnitEntry:
	var id: String
	var tier: String
	var display_name: String
	var icon: Texture2D

	func _init(p_id: String, p_tier: String, p_name: String, p_icon: Texture2D) -> void:
		id = p_id
		tier = p_tier
		display_name = p_name
		icon = p_icon


var roster: Array[UnitEntry] = []
var unlocked_count: int = STARTING_UNLOCKED

## Ids slotted into this run's ledger, in pick order. Capped at MAX_SLOTS.
var selected_ids: Array[String] = []


func _ready() -> void:
	_build_roster()


func _build_roster() -> void:
	roster = [
		UnitEntry.new("common_1", "common", "Raider I", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_01.png")),
		UnitEntry.new("common_2", "common", "Raider II", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_02.png")),
		UnitEntry.new("common_3", "common", "Raider III", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_04.png")),
		UnitEntry.new("common_4", "common", "Raider IV", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_03.png")),
		UnitEntry.new("common_5", "common", "Raider V", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_12.png")),
		UnitEntry.new("rare_1", "rare", "Marauder I", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_11.png")),
		UnitEntry.new("rare_2", "rare", "Marauder II", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_10.png")),
		UnitEntry.new("rare_3", "rare", "Marauder III", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_09.png")),
		UnitEntry.new("rare_4", "rare", "Marauder IV", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_06.png")),
		UnitEntry.new("rare_5", "rare", "Marauder V", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_14.png")),
		UnitEntry.new("boss", "boss", "The Reckoner", preload("res://Tiny/Tiny Swords (Free Pack)/UI Elements/UI from the page/Enemy Avatars/Enemy Avatars_16.png")),
	]


func is_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_count


func is_selected(id: String) -> bool:
	return selected_ids.has(id)


## Toggles `id` into/out of this run's ledger. No-ops if the unit is locked
## or the ledger is already full.
func toggle(id: String) -> void:
	var index := _index_of(id)
	if index == -1 or not is_unlocked(index):
		return
	if selected_ids.has(id):
		selected_ids.erase(id)
	elif selected_ids.size() < MAX_SLOTS:
		selected_ids.append(id)
	else:
		return
	selection_changed.emit()


func reset_selection() -> void:
	if selected_ids.is_empty():
		return
	selected_ids.clear()
	selection_changed.emit()


func roll_hint_for(tier: String) -> String:
	return TIER_ROLL_HINTS.get(tier, "")


## The units slotted into the ledger for the given tier - what main.gd
## should actually draw a drafted unit from when that tier's sum is rolled.
func entries_for_tier(tier: String) -> Array[UnitEntry]:
	var out: Array[UnitEntry] = []
	for entry in roster:
		if entry.tier == tier and selected_ids.has(entry.id):
			out.append(entry)
	return out


## The full ledger, in pick order - what the pre-run screen's slot row and
## the in-battle ledger readout both display.
func selected_entries() -> Array[UnitEntry]:
	var out: Array[UnitEntry] = []
	for id in selected_ids:
		var index := _index_of(id)
		if index != -1:
			out.append(roster[index])
	return out


func _index_of(id: String) -> int:
	for i in roster.size():
		if roster[i].id == id:
			return i
	return -1
