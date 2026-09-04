extends CanvasLayer

## Full-screen HUD layer. Owns the wave/village-HP labels and the win/lose
## banner. Scripts/main.gd (the dice roller, living inside the small
## SubViewport dice tray) reaches these through the "battle_hud" group and
## updates them by node name - see main.gd's _get_hud()/_update_hud().

@onready var dice_roller: Node2D = $UIRoot/TrayAnchor/DiceRollerContainer/DiceRollerViewport/DiceRoller
@onready var roll_button: Button = $UIRoot/RollButton
@onready var ui_root: Control = $UIRoot
@onready var tray_anchor: Control = $UIRoot/TrayAnchor

@onready var path_left: Sprite2D = $UIRoot/TrayAnchor/PathLeft
@onready var path_right: Sprite2D = $UIRoot/TrayAnchor/PathtRight
@onready var path_left_button: Button = $UIRoot/TrayAnchor/PathLeftButton
@onready var path_right_button: Button = $UIRoot/TrayAnchor/PathRightButton

const PATH_DIM := Color(0.55, 0.55, 0.55, 1.0)
const PATH_LIT := Color(1, 1, 1, 1)

const LEDGER_ICON_SIZE := Vector2(36, 36)

var _ledger_readout: HBoxContainer = null


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_button_pressed)
	path_left_button.pressed.connect(_on_path_left_pressed)
	path_right_button.pressed.connect(_on_path_right_pressed)
	_build_hud_labels()
	_update_path_highlight()
	set_battle_active(false)


## Shows/hides the dice tray and roll button, and gates dice_roller's own
## input handling - see main.gd's battle_started. village.gd calls this
## once with false at the start of the pre-siege planning phase, then true
## when the player hits "Start Siege" in LedgerUI.
func set_battle_active(active: bool) -> void:
	tray_anchor.visible = active
	roll_button.visible = active
	dice_roller.battle_started = active
	if active:
		_build_ledger_readout()


func _on_roll_button_pressed() -> void:
	dice_roller.trigger_roll()


## Click a path to send the next drafted unit's march out that portal
## instead. Purely which-side-they-walk-out-of for now - see main.gd's
## march_side/TODO(portal) comment for what's still undecided.
func _on_path_left_pressed() -> void:
	dice_roller.set_march_side("left")
	_update_path_highlight()


func _on_path_right_pressed() -> void:
	dice_roller.set_march_side("right")
	_update_path_highlight()


func _update_path_highlight() -> void:
	path_left.modulate = PATH_LIT if dice_roller.march_side == "left" else PATH_DIM
	path_right.modulate = PATH_LIT if dice_roller.march_side == "right" else PATH_DIM


func _build_hud_labels() -> void:
	var wave_label := Label.new()
	wave_label.name = "WaveLabel"
	wave_label.position = Vector2(16, 12)
	wave_label.text = "Wave 1/5"
	wave_label.add_theme_font_size_override("font_size", 22)
	ui_root.add_child(wave_label)

	var hp_label := Label.new()
	hp_label.name = "VillageHPLabel"
	hp_label.position = Vector2(16, 44)
	hp_label.text = "Village HP: 20/20"
	hp_label.add_theme_font_size_override("font_size", 22)
	ui_root.add_child(hp_label)

	var banner := Label.new()
	banner.name = "ResultBanner"
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 28)
	ui_root.add_child(banner)


## The units locked into this run's ledger (icon + what it takes to roll
## them), shown once the siege starts so the player can see at a glance
## what they slotted in during planning. Rebuilt each time set_battle_active
## turns the battle on, since the ledger selection is only final at that
## point.
func _build_ledger_readout() -> void:
	if _ledger_readout:
		_ledger_readout.queue_free()
	_ledger_readout = HBoxContainer.new()
	_ledger_readout.name = "LedgerReadout"
	_ledger_readout.add_theme_constant_override("separation", 10)
	_ledger_readout.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_ledger_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_ledger_readout)

	for entry in Ledger.selected_entries():
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = entry.icon
		icon.custom_minimum_size = LEDGER_ICON_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon)
		var cost := Label.new()
		cost.text = Ledger.roll_hint_for(entry.tier)
		cost.add_theme_font_size_override("font_size", 10)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(cost)
		_ledger_readout.add_child(vbox)
