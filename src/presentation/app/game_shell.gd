extends Node

## Game application shell: CS-styled main menu -> map select -> walkable map.
##
## Player-facing entry (res://scenes/app/Main.tscn), distinct from src/dev labs.
## Reuses src/core asset/map loading and the src/game authoritative session; it
## must not import dev-lab code. The CS look (background tiles, menu sounds,
## fonts) is loaded from the player's local install through the VFS, never
## bundled; only OpenStrike code (theme/loaders) is committed.
##
## Collision under the walkable map is still the non-parity Godot backend until
## the GoldSrc clipnode trace lands; the in-map overlay says so.

class_name OpenStrikeGameShell

const AssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const GoldSrcVFSRef = preload("res://src/core/assets/goldsrc_vfs.gd")
const WalkableWorldRef = preload("res://src/presentation/app/walkable_world.gd")
const LocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")
const CSSchemeRef = preload("res://src/presentation/ui/cs_scheme.gd")
const CSUiSoundsRef = preload("res://src/presentation/ui/cs_ui_sounds.gd")
const CSBackgroundRef = preload("res://src/presentation/ui/cs_background.gd")

const MAPS_DIR := "maps"
const MAP_EXTENSIONS: Array[String] = ["bsp"]
const LOADING_SCREEN_MIN_SECONDS := 0.18

var config_path := LocalConfigRef.DEFAULT_CONFIG_PATH

var _asset_manager = null
var _sounds = null
var _ui_layer: CanvasLayer = null
var _background: Control = null
var _screen_root: Control = null
var _world: Node3D = null
var _menu_theme: Theme = null
var _dialog_theme: Theme = null
var _selected_map_path := ""
var _load_generation := 0


func _ready() -> void:
	_apply_fullscreen()
	_asset_manager = AssetManagerRef.create_from_config_path(config_path)
	_menu_theme = CSSchemeRef.main_menu_theme()
	_dialog_theme = CSSchemeRef.dialog_theme()

	_sounds = CSUiSoundsRef.new()
	_sounds.configure(self, _asset_manager)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ShellUI"
	add_child(_ui_layer)

	_background = CSBackgroundRef.build(_asset_manager)
	if _background == null:
		_background = _fallback_background()
	_ui_layer.add_child(_background)

	show_main_menu()


func show_main_menu() -> void:
	_load_generation += 1
	_teardown_world()
	_set_ui_visible(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_selected_map_path = ""

	var screen := _new_screen()
	screen.theme = _menu_theme

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.anchor_left = 0.0
	column.anchor_right = 0.0
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.grow_horizontal = Control.GROW_DIRECTION_END
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = 170.0
	column.offset_top = -375.0
	column.offset_bottom = -58.0
	screen.add_child(column)

	# Faithful CS main-menu item set; only New game and Quit are wired yet.
	column.add_child(_menu_item("New game", show_map_select))
	column.add_child(_menu_item("Find servers", Callable()))
	column.add_child(_menu_item("Options", Callable()))
	column.add_child(_menu_item("Quit", _quit))


func show_map_select() -> void:
	_set_ui_visible(true)
	var screen := _new_screen()
	screen.theme = _dialog_theme

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(670.0, 495.0)
	window.anchor_left = 0.0
	window.anchor_right = 0.0
	window.anchor_top = 0.0
	window.anchor_bottom = 0.0
	window.offset_left = 625.0
	window.offset_top = 385.0
	window.offset_right = 1295.0
	window.offset_bottom = 880.0
	screen.add_child(window)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	window.add_child(frame)

	# Title bar: "Create Server" with an X close button, like the CS dialog.
	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", CSSchemeRef.title_bar_box())
	title_bar.custom_minimum_size = Vector2(0.0, 34.0)
	frame.add_child(title_bar)
	var title_row := HBoxContainer.new()
	title_bar.add_child(title_row)
	var title := Label.new()
	title.text = "Create Server"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.custom_minimum_size = Vector2(34.0, 30.0)
	close.pressed.connect(show_main_menu)
	if _sounds != null:
		_sounds.attach(close)
	title_row.add_child(close)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	frame.add_child(tab_row)
	tab_row.add_child(_dialog_tab("Server", true))
	tab_row.add_child(_dialog_tab("Game", false))
	tab_row.add_child(_dialog_tab("CPU Player Options", false))

	# Body with margins inside the olive create-server window.
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 48)
	body.add_theme_constant_override("margin_right", 48)
	body.add_theme_constant_override("margin_top", 36)
	body.add_theme_constant_override("margin_bottom", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(body)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	body.add_child(column)

	var maps := _scan_maps()
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 14)
	column.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Map"
	map_label.custom_minimum_size = Vector2(90.0, 0.0)
	map_row.add_child(map_label)

	var map_select := OptionButton.new()
	map_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CSSchemeRef.style_combobox(map_select)
	map_row.add_child(map_select)

	if maps.is_empty():
		map_select.add_item("No maps found")
		map_select.disabled = true
		var note := Label.new()
		note.text = (
			"No maps found.\n"
			+ "Point user://local_goldsrc.json at a licensed CS 1.6 install\n"
			+ "with a cstrike/maps folder of .bsp files."
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(note)
	else:
		for map_index in maps.size():
			var map_entry: Dictionary = maps[map_index]
			map_select.add_item(str(map_entry.get("stem", map_entry.get("name", "map"))))
			map_select.set_item_metadata(map_index, str(map_entry.get("relative_path", "")))
		_selected_map_path = str(map_select.get_item_metadata(0))
		map_select.item_selected.connect(_on_map_option_selected.bind(map_select))

	column.add_child(CSSchemeRef.separator())

	column.add_child(_indicator_row("Include CPU players (Bots) in this game", true, true))

	var bots_row := HBoxContainer.new()
	bots_row.add_theme_constant_override("separation", 14)
	bots_row.modulate = Color(1.0, 1.0, 1.0, 0.58)
	column.add_child(bots_row)
	var bot_count_label := Label.new()
	bot_count_label.text = "Number of CPU players"
	bot_count_label.custom_minimum_size = Vector2(210.0, 0.0)
	bots_row.add_child(bot_count_label)
	var bot_count := LineEdit.new()
	bot_count.text = "9"
	bot_count.editable = false
	bot_count.custom_minimum_size = Vector2(74.0, 28.0)
	bots_row.add_child(bot_count)

	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty"
	difficulty_label.modulate = Color(1.0, 1.0, 1.0, 0.58)
	column.add_child(difficulty_label)
	for difficulty in ["Easy", "Normal", "Hard", "Expert"]:
		column.add_child(_indicator_row(difficulty, difficulty == "Easy", false))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	column.add_child(CSSchemeRef.separator())

	# Action buttons bottom-right: Start / Cancel, like the original dialog.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var start := Button.new()
	start.text = "Start"
	start.disabled = maps.is_empty()
	if not start.disabled:
		start.pressed.connect(_start_selected_map)
	if _sounds != null and not start.disabled:
		_sounds.attach(start)
	actions.add_child(start)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(show_main_menu)
	if _sounds != null:
		_sounds.attach(cancel)
	actions.add_child(cancel)


func _start_selected_map() -> void:
	if _selected_map_path == "":
		return
	_load_generation += 1
	var load_generation := _load_generation
	_show_loading_screen(_selected_map_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(LOADING_SCREEN_MIN_SECONDS).timeout
	if load_generation != _load_generation:
		return
	_start_map(_selected_map_path)


func _on_map_option_selected(index: int, option: OptionButton) -> void:
	if option == null or index < 0:
		_selected_map_path = ""
		return
	_selected_map_path = str(option.get_item_metadata(index))


func _menu_item(text: String, on_pressed: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(310.0, 55.0)
	button.disabled = disabled
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not disabled and on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	if _sounds != null and not disabled:
		_sounds.attach(button)
	return button


func _dialog_tab(text: String, active: bool, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_NONE
	CSSchemeRef.style_dialog_tab(button, active, disabled)
	return button


func _indicator_row(text: String, selected: bool, amber_text: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.modulate = Color(1.0, 1.0, 1.0, 0.84 if amber_text else 0.58)

	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(14.0, 14.0)
	indicator.color = CSSchemeRef.progress_segment_color() if selected else CSSchemeRef.field_dark_color()
	row.add_child(indicator)

	var label := Label.new()
	label.text = text
	label.modulate = CSSchemeRef.amber_color() if amber_text else Color(1.0, 1.0, 1.0, 0.9)
	row.add_child(label)
	return row


func _show_loading_screen(_map_path: String) -> void:
	_set_ui_visible(true)
	var screen := _new_screen()
	screen.theme = _dialog_theme

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CSSchemeRef.loading_panel_box())
	panel.custom_minimum_size = Vector2(760.0, 168.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -380.0
	panel.offset_top = 88.0
	panel.offset_right = 380.0
	panel.offset_bottom = 256.0
	screen.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Loading..."
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.95, 0.95, 0.9, 1.0)
	column.add_child(title)

	var status := Label.new()
	status.text = "Precaching resources..."
	status.add_theme_font_size_override("font_size", 22)
	status.modulate = Color(0.73, 0.75, 0.68, 0.92)
	column.add_child(status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	row.add_child(_segmented_loading_bar())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(130.0, 42.0)
	cancel.pressed.connect(_cancel_loading)
	if _sounds != null:
		_sounds.attach(cancel)
	row.add_child(cancel)


func _segmented_loading_bar() -> PanelContainer:
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(470.0, 42.0)
	track.add_theme_stylebox_override("panel", CSSchemeRef.progress_track_box())

	var segments := HBoxContainer.new()
	segments.add_theme_constant_override("separation", 5)
	track.add_child(segments)
	for _index in range(18):
		var segment := ColorRect.new()
		segment.color = CSSchemeRef.progress_segment_color()
		segment.custom_minimum_size = Vector2(18.0, 30.0)
		segments.add_child(segment)
	return track


func _cancel_loading() -> void:
	_load_generation += 1
	show_map_select()


func _scan_maps() -> Array[Dictionary]:
	if _asset_manager == null or _asset_manager.local_config == null:
		return []
	var cstrike_dir := str(_asset_manager.local_config.cstrike_dir)
	if cstrike_dir == "":
		return []
	var cstrike_vfs = GoldSrcVFSRef.new()
	cstrike_vfs.configure([cstrike_dir])
	if not cstrike_vfs.is_available():
		return []
	return cstrike_vfs.list_files(MAPS_DIR, MAP_EXTENSIONS)


func _start_map(map_path: String) -> void:
	if map_path == "":
		return
	_teardown_world()

	var world = WalkableWorldRef.new()
	world.name = "WalkableWorld"
	_world = world
	world.exit_requested.connect(show_main_menu)
	add_child(world)

	var started: Dictionary = world.start_map(_asset_manager, map_path)
	if not bool(started.get("ok", false)):
		_teardown_world()
		_show_load_error(map_path, started)
		return

	_set_ui_visible(false)


func _show_load_error(map_path: String, result: Dictionary) -> void:
	_set_ui_visible(true)
	var screen := _new_screen()
	screen.theme = _dialog_theme
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var note := Label.new()
	note.text = "Could not load %s\n%s" % [map_path, str(result.get("reason", "see diagnostics"))]
	column.add_child(note)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(show_map_select)
	if _sounds != null:
		_sounds.attach(back)
	column.add_child(back)


func _teardown_world() -> void:
	if _world != null:
		_world.queue_free()
		_world = null


func _set_ui_visible(visible: bool) -> void:
	if _ui_layer != null:
		_ui_layer.visible = visible


func _new_screen() -> Control:
	if _screen_root != null:
		_screen_root.queue_free()
		_screen_root = null
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)
	_screen_root = root
	return root


func _fallback_background() -> Control:
	var rect := ColorRect.new()
	rect.color = Color(0.06, 0.07, 0.09, 1.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window != null:
		window.mode = Window.MODE_FULLSCREEN


func _quit() -> void:
	get_tree().quit(0)
