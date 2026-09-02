extends CanvasLayer

## Full-screen HUD layer. Owns the wave/village-HP labels and the win/lose
## banner. Scripts/main.gd (the dice roller, living inside the small
## SubViewport dice tray) reaches these through the "battle_hud" group and
## updates them by node name - see main.gd's _get_hud()/_update_hud().

@onready var dice_roller: Node2D = $UIRoot/DiceRollerContainer/DiceRollerViewport/DiceRoller
@onready var roll_button: Button = $UIRoot/RollButton
@onready var ui_root: Control = $UIRoot


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_button_pressed)
	_build_hud_labels()


func _on_roll_button_pressed() -> void:
	dice_roller.trigger_roll()


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
