extends CanvasLayer

## Full-screen HUD layer. Owns the win/lose banner (currently unused - it
## was set by the now-cut CLASH phase's _end_run()). Scripts/main.gd (the
## dice roller, living inside the small SubViewport dice tray) reaches it
## through the "battle_hud" group and updates it by node name - see
## main.gd's _get_hud().

@onready var dice_roller: Node2D = $UIRoot/TrayAnchor/DiceRollerContainer/DiceRollerViewport/DiceRoller
@onready var roll_button: Button = $UIRoot/RollButton
@onready var ui_root: Control = $UIRoot

@onready var path_left: Sprite2D = $UIRoot/TrayAnchor/PathLeft
@onready var path_right: Sprite2D = $UIRoot/TrayAnchor/PathtRight
@onready var path_left_button: Button = $UIRoot/TrayAnchor/PathLeftButton
@onready var path_right_button: Button = $UIRoot/TrayAnchor/PathRightButton

const PATH_DIM := Color(0.55, 0.55, 0.55, 1.0)
const PATH_LIT := Color(1, 1, 1, 1)

## Built lazily in _build_ledger_ui() rather than existing in
## battle_ui.tscn - see that function for why.
var ledger_panel: PanelContainer
var ledger_label: Label


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_button_pressed)
	path_left_button.pressed.connect(_on_path_left_pressed)
	path_right_button.pressed.connect(_on_path_right_pressed)
	_build_hud_labels()
	_build_ledger_ui()
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


## Wave/village-HP labels used to live here, driven by the CLASH phase's
## _resolve_clash(). CLASH is cut from the active loop for now (see
## main.gd's Phase enum comment) - it never updates them anymore - so
## they're left out rather than sitting on screen frozen at "Wave 1/5".
func _build_hud_labels() -> void:
	var banner := Label.new()
	banner.name = "ResultBanner"
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 28)
	ui_root.add_child(banner)


## The "roll ledger" from the design doc - a clickable sheet showing which
## dice-sum ranges currently draft which units. Built here at runtime
## rather than as nodes in battle_ui.tscn since its whole point is to
## reflect main.gd's live pools/names (see get_ledger_rows()) rather than
## static scene content - there's nothing meaningful to hand-author.
func _build_ledger_ui() -> void:
	var button := Button.new()
	button.name = "LedgerButton"
	button.text = "Ledger"
	button.position = Vector2(16, 12)
	button.size = Vector2(90, 32)
	button.pressed.connect(_on_ledger_button_pressed)
	ui_root.add_child(button)

	ledger_panel = PanelContainer.new()
	ledger_panel.name = "LedgerPanel"
	ledger_panel.position = Vector2(16, 52)
	ledger_panel.visible = false
	ui_root.add_child(ledger_panel)

	ledger_label = Label.new()
	ledger_label.add_theme_font_size_override("font_size", 16)
	ledger_panel.add_child(ledger_label)


func _on_ledger_button_pressed() -> void:
	ledger_panel.visible = not ledger_panel.visible
	if ledger_panel.visible:
		ledger_label.text = "\n".join(dice_roller.get_ledger_rows())
