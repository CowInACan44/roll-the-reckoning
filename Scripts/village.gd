extends Node2D
## Root of village.tscn. Runs the pre-siege planning phase: shows LedgerUI
## over the pannable village, keeps the battle UI (dice tray/roll button)
## hidden and rolling disabled until the player hits "Start Siege", then
## hands off into the normal wave loop that already lived in battle_ui/
## main.gd.

@onready var battle_ui := $BattleUI
@onready var world_camera: Camera2D = $Node2D/WorldCamera


func _ready() -> void:
	Ledger.reset_selection()
	battle_ui.set_battle_active(false)

	var ledger_ui := LedgerUI.new()
	add_child(ledger_ui)
	ledger_ui.siege_started.connect(_on_siege_started)


func _on_siege_started() -> void:
	world_camera.reset_to_battle_view()
	battle_ui.set_battle_active(true)
