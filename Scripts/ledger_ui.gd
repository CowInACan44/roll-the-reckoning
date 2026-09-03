extends CanvasLayer
class_name LedgerUI
## The pre-siege planning overlay: a thin bar over the (pannable) village
## view with "Open Ledger"/"Start Siege" buttons, plus the ledger panel
## itself where the player slots up to Ledger.MAX_SLOTS unlocked units into
## this run's roll pool. Built entirely in code (same idiom as
## battle_ui.gd's _build_hud_labels) so there's no hand-authored .tscn
## layout to get wrong without an editor to check it in.

signal siege_started

const ICON_SIZE := Vector2(48, 48)
const LOCKED_MODULATE := Color(0.3, 0.3, 0.3, 0.7)
const UNSELECTED_MODULATE := Color(1, 1, 1, 0.55)
const SELECTED_MODULATE := Color(1, 1, 1, 1)

var _ledger_panel: PanelContainer
var _slot_row: HBoxContainer
var _roster_row: HBoxContainer
var _roster_buttons: Dictionary = {}  # unit id (String) -> TextureButton


func _ready() -> void:
	_build_ui()
	Ledger.selection_changed.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var prep_bar := PanelContainer.new()
	prep_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	prep_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(prep_bar)

	var prep_box := HBoxContainer.new()
	prep_box.add_theme_constant_override("separation", 16)
	prep_bar.add_child(prep_box)

	var hint := Label.new()
	hint.text = "Plan your siege - drag to scroll the village, then open the ledger."
	prep_box.add_child(hint)

	var open_button := Button.new()
	open_button.text = "Open Ledger"
	open_button.pressed.connect(_on_open_ledger_pressed)
	prep_box.add_child(open_button)

	var start_button := Button.new()
	start_button.text = "Start Siege"
	start_button.pressed.connect(_on_start_pressed)
	prep_box.add_child(start_button)

	_ledger_panel = PanelContainer.new()
	_ledger_panel.visible = false
	_ledger_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_ledger_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_ledger_panel)

	var ledger_box := VBoxContainer.new()
	ledger_box.add_theme_constant_override("separation", 12)
	_ledger_panel.add_child(ledger_box)

	var title := Label.new()
	title.text = "Ledger - choose up to %d units to roll for" % Ledger.MAX_SLOTS
	ledger_box.add_child(title)

	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 8)
	ledger_box.add_child(_slot_row)

	_roster_row = HBoxContainer.new()
	_roster_row.add_theme_constant_override("separation", 8)
	ledger_box.add_child(_roster_row)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	ledger_box.add_child(close_button)

	_build_roster_buttons()


func _build_roster_buttons() -> void:
	for entry in Ledger.roster:
		var button := TextureButton.new()
		button.texture_normal = entry.icon
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = ICON_SIZE
		button.tooltip_text = "%s\n%s" % [entry.display_name, Ledger.roll_hint_for(entry.tier)]
		button.pressed.connect(_on_roster_button_pressed.bind(entry.id))
		_roster_row.add_child(button)
		_roster_buttons[entry.id] = button


func _on_roster_button_pressed(id: String) -> void:
	Ledger.toggle(id)


func _on_open_ledger_pressed() -> void:
	_ledger_panel.visible = true


func _on_close_pressed() -> void:
	_ledger_panel.visible = false


func _on_start_pressed() -> void:
	if Ledger.selected_ids.is_empty():
		return
	siege_started.emit()
	queue_free()


func _refresh() -> void:
	for i in Ledger.roster.size():
		var entry = Ledger.roster[i]
		var button: TextureButton = _roster_buttons[entry.id]
		var unlocked := Ledger.is_unlocked(i)
		button.disabled = not unlocked
		if not unlocked:
			button.modulate = LOCKED_MODULATE
		elif Ledger.is_selected(entry.id):
			button.modulate = SELECTED_MODULATE
		else:
			button.modulate = UNSELECTED_MODULATE

	for child in _slot_row.get_children():
		child.queue_free()
	var selected := Ledger.selected_entries()
	for entry in selected:
		_slot_row.add_child(_build_slot_display(entry.icon, Ledger.roll_hint_for(entry.tier)))
	for i in range(selected.size(), Ledger.MAX_SLOTS):
		var empty := ColorRect.new()
		empty.color = Color(1, 1, 1, 0.08)
		empty.custom_minimum_size = ICON_SIZE
		_slot_row.add_child(empty)


func _build_slot_display(icon: Texture2D, cost_text: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = ICON_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon_rect)
	var cost := Label.new()
	cost.text = cost_text
	cost.add_theme_font_size_override("font_size", 10)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost)
	return vbox
