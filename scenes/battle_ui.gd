extends CanvasLayer

## Full-screen HUD layer. Owns the wave/village-HP labels and the win/lose
## banner. Scripts/main.gd (the dice roller, living inside the small
## SubViewport dice tray) reaches these through the "battle_hud" group and
## updates them by node name - see main.gd's _get_hud()/_update_hud().

@onready var dice_roller: Node2D = $UIRoot/TrayAnchor/DiceRollerContainer/DiceRollerViewport/DiceRoller
@onready var roll_button: Button = $UIRoot/RollButton
@onready var ui_root: Control = $UIRoot

@onready var path_left: Sprite2D = $UIRoot/TrayAnchor/PathLeft
@onready var path_right: Sprite2D = $UIRoot/TrayAnchor/PathtRight
@onready var path_left_button: Button = $UIRoot/TrayAnchor/PathLeftButton
@onready var path_right_button: Button = $UIRoot/TrayAnchor/PathRightButton

const PATH_DIM := Color(0.55, 0.55, 0.55, 1.0)
const PATH_LIT := Color(1, 1, 1, 1)


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_button_pressed)
	path_left_button.pressed.connect(_on_path_left_pressed)
	path_right_button.pressed.connect(_on_path_right_pressed)
	_build_hud_labels()
	_update_path_highlight()


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
